'use strict';

const $ = (id) => document.getElementById(id);
const keyInput = $('key');
const connectButton = $('connect');
const restoreButton = $('restore');
const removeButton = $('remove-models');
const shell = $('shell');

// One panel, three tools. Codex is the default and the main one; the image
// tool and the domestic model import are reached from small entries lower
// down and reuse the same card, field and button.
const TOOLS = {
  codex: {
    label: 'Codex 状态',
    button: '一键连接 Codex',
    placeholder: '粘贴 API Key，或在网站点「一键导入」',
  },
  image: {
    label: '生图工具',
    button: '一键导入生图工具',
    placeholder: '粘贴画图分组的 API Key，或在网站点「一键导入」',
    tag: '现在导入的是：生图工具的 Key',
    guide: '到网站「API 密钥」页或首页，选画图分组的密钥点「一键导入」，或复制粘贴到上面。导入完成前不要关闭本窗口。',
  },
  models: {
    label: '国产模型',
    button: '导入国产模型',
    tag: '把国产模型加入 Codex 的模型列表',
    guide: '不需要密钥。GPT、当前接口和 Key 都保留，导入后在 Codex 新建任务时选择模型。导入完成会自动关闭 Codex。',
  },
};
const CODEX_TITLES = {
  usegoodai: '已连接 UseGoodAI',
  none: '还没连接',
  other: '当前用的是官方登录或其他服务',
};
const CONFIRM_MS = 6000;

let busy = false;
let tool = 'codex';
let state = { status: null, image: null, models: null };
let confirming = null; // 'import' or 'remove' while waiting for a second click
let confirmTimer = 0;
const queuedLinks = [];

function bridge() {
  return window.go && window.go.main && window.go.main.App;
}

function waitForBridge() {
  return new Promise((resolve) => {
    const started = Date.now();
    (function check() {
      if (bridge() && window.runtime) return resolve(bridge());
      if (Date.now() - started > 5000) return resolve(bridge());
      setTimeout(check, 30);
    })();
  });
}

// The card at the top shows whichever tool is open.
function cardFor() {
  if (tool === 'image') {
    const image = state.image || { state: 'none' };
    const titles = {
      none: '未安装',
      ready: `V${image.version} 已安装`,
      nokey: `V${image.version} 已安装，缺少 Key`,
      outdated: `V${image.version} 已安装，可更新到 V${image.bundled}`,
      unmanaged: '有生图文件，但无法确认版本',
    };
    const ok = image.state === 'ready';
    return {
      state: ok ? 'ok' : image.state === 'none' ? 'none' : 'other',
      title: titles[image.state] || titles.none,
      name: image.shared ? '与 Codex 共用' : image.name || '',
      key: image.key || '',
    };
  }
  if (tool === 'models') {
    const models = state.models || { state: 'none' };
    if (models.state === 'active') return { state: 'ok', title: `已导入 ${models.count} 个国产模型`, name: '', key: '' };
    if (models.state === 'inactive') {
      return { state: 'other', title: '已失效，需要重新导入', name: '', key: '重新连接 Codex 后要再导入一次' };
    }
    return { state: 'none', title: '还没导入', name: '', key: '' };
  }
  const status = state.status || { state: 'none' };
  const connected = status.state === 'usegoodai';
  return {
    state: connected ? 'ok' : status.state === 'none' ? 'none' : 'other',
    title: CODEX_TITLES[status.state] || CODEX_TITLES.other,
    name: connected ? status.name || '' : '',
    key: connected ? status.key || '' : '',
  };
}

function renderCard() {
  const card = cardFor();
  $('status').dataset.state = card.state;
  $('status-label').textContent = TOOLS[tool].label;
  $('status-title').textContent = card.title;
  $('status-key').textContent = card.key;
  const name = $('status-name');
  name.textContent = card.name;
  name.title = card.name;
  name.hidden = card.name === '';
}

// The entries say what is already done, so nobody installs twice by mistake.
function renderEntries() {
  const image = state.image || { state: 'none' };
  const imageLabels = {
    ready: '生图工具（已安装）',
    outdated: '生图工具（可更新）',
    nokey: '生图工具（缺少 Key）',
  };
  $('go-image-label').textContent = imageLabels[image.state] || '安装生图工具';
  $('go-image').dataset.state = image.state === 'ready' ? 'done' : image.state === 'none' ? '' : 'attention';

  const models = state.models || { state: 'none' };
  let modelsLabel = '导入国产模型';
  if (models.state === 'active') modelsLabel = '国产模型（已导入）';
  else if (models.state === 'inactive') modelsLabel = '国产模型（已失效）';
  $('go-models-label').textContent = modelsLabel;
  $('go-models').dataset.state = models.state === 'active' ? 'done' : models.state === 'inactive' ? 'attention' : '';

  for (const name of ['codex', 'image', 'models']) {
    $(`go-${name}`).hidden = name === tool;
  }
}

function idleLabel() {
  if (tool === 'models') {
    if (confirming === 'import') return '确认导入（会关闭 Codex）';
    return state.models && state.models.state === 'active' ? '重新导入国产模型' : TOOLS.models.button;
  }
  return TOOLS[tool].button;
}

function render() {
  renderCard();
  renderEntries();
  if (!busy) $('connect-label').textContent = idleLabel();
  connectButton.classList.toggle('confirm', confirming === 'import');
  removeButton.hidden = tool !== 'models' || !state.models || state.models.state === 'none';
  removeButton.textContent = confirming === 'remove' ? '确认移除（会关闭 Codex）' : '移除国产模型';
  $('restore-anchor').hidden = tool !== 'codex';
}

function absorb(result) {
  if (result.status) state.status = result.status;
  if (result.image) state.image = result.image;
  if (result.models) state.models = result.models;
}

function showNotice(tone, text, action, tag) {
  const notice = $('notice');
  notice.dataset.tone = tone;
  const paragraph = $('notice-text');
  paragraph.textContent = text;
  if (tag) {
    const strong = document.createElement('strong');
    strong.className = 'mode-tag';
    strong.textContent = tag;
    paragraph.prepend(strong);
  }
  $('notice-action').hidden = action !== 'open-site';
  notice.hidden = false;
}

function showResult(result) {
  absorb(result);
  render();
  showNotice(result.tone, result.message, result.action);
}

function setBusy(on, label) {
  busy = on;
  for (const button of [connectButton, restoreButton, removeButton, $('go-codex'), $('go-image'), $('go-models')]) {
    button.disabled = on;
  }
  connectButton.classList.toggle('busy', on);
  $('connect-label').textContent = on ? label : idleLabel();
}

function cancelConfirm() {
  clearTimeout(confirmTimer);
  confirming = null;
}

function askConfirm(what) {
  cancelConfirm();
  confirming = what;
  confirmTimer = setTimeout(() => {
    confirming = null;
    render();
  }, CONFIRM_MS);
  render();
}

function setTool(next) {
  if (next === tool) return;
  cancelConfirm();
  tool = next;
  shell.dataset.tool = tool;
  keyInput.value = '';
  if (TOOLS[tool].placeholder) keyInput.placeholder = TOOLS[tool].placeholder;
  shell.classList.remove('activating');
  void shell.offsetWidth; // restart the sweep
  shell.classList.add('activating');
  setTimeout(() => shell.classList.remove('activating'), 950);
  render();
  if (tool === 'codex') {
    $('notice').hidden = true;
  } else {
    showNotice(tool, TOOLS[tool].guide, tool === 'image' ? 'open-site' : '', TOOLS[tool].tag);
  }
  if (tool === 'image') keyInput.focus();
}

async function run(label, notice, action) {
  setBusy(true, label);
  showNotice('info', notice);
  try {
    const result = await action();
    // A finished image install or model import goes back to Codex; the
    // result stays on screen.
    if (tool !== 'codex' && result.tone !== 'error') setTool('codex');
    showResult(result);
  } catch (error) {
    showNotice('error', '操作没有完成，请再试一次。');
  } finally {
    setBusy(false);
    nextLink();
  }
}

function submit() {
  if (tool === 'models') {
    if (confirming !== 'import') {
      askConfirm('import');
      return;
    }
    cancelConfirm();
    run('正在导入…', '正在导入国产模型…', () => bridge().ImportModels());
    return;
  }
  const key = keyInput.value;
  if (tool === 'image') {
    run('正在安装…', '正在检查密钥能否画图…', () => bridge().InstallImage(key));
    return;
  }
  run('正在连接…', '正在检查密钥…', () => bridge().Connect(key));
}

// Links import straight away. On the image tool they go to the image tool;
// anywhere else they connect Codex, as they always have.
async function importLink(raw) {
  setBusy(true, '正在连接…');
  let parsed = null;
  try {
    parsed = await bridge().ParseLink(raw);
  } catch (error) {
    parsed = null;
  }
  if (!parsed || !parsed.ok) {
    setBusy(false);
    if (parsed) showResult(parsed.result);
    else showNotice('error', '操作没有完成，请再试一次。');
    nextLink();
    return;
  }
  const name = parsed.name || '';
  if (tool === 'image') {
    keyInput.value = parsed.key;
    const notice = name ? `正在把「${name}」导入生图工具…` : '正在把密钥导入生图工具…';
    await run('正在安装…', notice, () => bridge().ImportImage(parsed.key, name));
    return;
  }
  if (tool !== 'codex') setTool('codex');
  keyInput.value = parsed.key;
  const notice = name ? `正在导入「${name}」…` : '正在导入密钥…';
  await run('正在连接…', notice, () => bridge().Import(parsed.key, name));
}

function enqueueLink(raw) {
  if (!raw) return;
  queuedLinks.push(raw);
  nextLink();
}

function nextLink() {
  if (busy || queuedLinks.length === 0) return;
  importLink(queuedLinks.shift());
}

async function fillFromClipboard() {
  if (busy || tool === 'models' || keyInput.value.trim() !== '' || !bridge()) return;
  try {
    const key = await bridge().ClipboardKey();
    if (key && keyInput.value.trim() === '') keyInput.value = key;
  } catch (error) {
    // The clipboard may be busy; the user can still paste by hand.
  }
}

$('connect-form').addEventListener('submit', (event) => {
  event.preventDefault();
  if (!busy) submit();
});

for (const name of ['codex', 'image', 'models']) {
  $(`go-${name}`).addEventListener('click', () => {
    if (!busy) setTool(name);
  });
}

removeButton.addEventListener('click', () => {
  if (busy) return;
  if (confirming !== 'remove') {
    askConfirm('remove');
    return;
  }
  cancelConfirm();
  run('正在移除…', '正在移除国产模型…', () => bridge().RemoveModels());
});

restoreButton.addEventListener('click', () => {
  if (!busy) run('正在恢复…', '正在恢复官方登录…', () => bridge().Restore());
});

$('copy-qq').addEventListener('click', async (event) => {
  const button = event.currentTarget;
  if (await bridge().CopyGroupNumber()) {
    button.textContent = '已复制';
    button.classList.add('done');
    setTimeout(() => {
      button.textContent = '复制群号';
      button.classList.remove('done');
    }, 1600);
  }
});

$('notice-action').addEventListener('click', () => bridge().OpenSite());
$('join-qq').addEventListener('click', () => bridge().JoinGroup());
$('open-site').addEventListener('click', () => bridge().OpenSite());

window.addEventListener('focus', fillFromClipboard);
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') fillFromClipboard();
});

(async function start() {
  const app = await waitForBridge();
  if (!app) return;
  const info = await app.Info();
  $('version').textContent = info.version;
  state.status = await app.Status();
  state.image = await app.ImageStatus();
  state.models = await app.ModelsStatus();
  render();
  window.runtime.EventsOn('import-link', enqueueLink);
  const link = await app.TakeLaunchLink();
  if (link) {
    enqueueLink(link);
  } else {
    fillFromClipboard();
  }
})();
