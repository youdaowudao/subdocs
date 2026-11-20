'use strict';

const $ = (id) => document.getElementById(id);
const keyInput = $('key');
const connectButton = $('connect');
const restoreButton = $('restore');
const removeButton = $('remove-models');
const chineseButton = $('run-chinese');
const shell = $('shell');

// One panel, four tools. Codex and Claude are the two main ones, picked by
// the tabs at the top; Codex is the default. The image tool and domestic
// model import share the same status card, form and primary button.
const TOOLS = {
  codex: {
    label: 'Codex 状态',
    title: '将 Codex 接入 UseGoodAI',
    steps: '选编程分组的密钥，点「一键导入 Codex」。',
    button: '一键连接 Codex',
    placeholder: '也可以粘贴编程分组的 API Key',
    restoreTip: '取消中转站连接：Codex 改回用 OpenAI 官方账号登录，并关闭正在运行的 Codex。',
  },
  image: {
    label: '生图工具',
    button: '一键导入生图工具',
    placeholder: '粘贴画图分组的 API Key，或在网站点「一键导入」',
    tag: '现在导入的是：生图工具的 Key',
    guide: '到网站「API 密钥」页或首页，选画图分组的密钥点「一键导入」，或复制粘贴到上面。导入完成前不要关闭本窗口。',
  },
  claude: {
    label: 'Claude 桌面版',
    title: '将 Claude 桌面版接入 UseGoodAI',
    steps: '选 Claude 分组的密钥，点「一键导入 Claude」。',
    button: '一键连接 Claude',
    placeholder: '也可以粘贴 Claude 分组的 API Key',
    restoreTip: '取消中转站连接：Claude 改回用 Anthropic 官方账号登录，并关闭正在运行的 Claude。',
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
const CLAUDE_TITLES = {
  notinstalled: '没检测到 Claude 桌面版',
  usegoodai: '已连接 UseGoodAI',
  none: '还没连接',
  other: '当前用的是其他第三方服务',
};
const CONFIRM_MS = 6000;

let busy = false;
let tool = 'codex';
let state = { status: null, image: null, models: null, claude: null };
let confirming = null; // 'import' or 'remove' while waiting for a second click
let confirmTimer = 0;
const queuedLinks = [];
let activeLink = null;
let assistantUpdateDownloaded = false;

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
      title: image.updateAvailable
        ? `V${image.version} 已安装，可更新到 V${image.bundled}${image.key ? '' : '，尚未配置 Key'}`
        : titles[image.state] || titles.none,
      name: image.shared ? '与 Codex 共用' : image.name || '',
      key: image.key || '',
    };
  }
  if (tool === 'models') {
    const models = state.models || { state: 'none' };
    if (models.state === 'active') return { state: 'ok', title: `已导入 ${models.count} 个国产模型`, name: '', key: '' };
    if (models.state === 'inactive') {
      return { state: 'other', title: '需要重新导入', name: '', key: '重新连接 Codex 后，国产模型要再导入一次' };
    }
    return { state: 'none', title: '还没导入', name: '', key: '' };
  }
  if (tool === 'claude') {
    const claude = state.claude || { state: 'none' };
    const connected = claude.state === 'usegoodai';
    if (claude.state === 'notinstalled') {
      return { state: 'none', title: CLAUDE_TITLES.notinstalled, name: '', key: '先装好软件，再回来点一键连接', download: true };
    }
    return {
      state: connected ? 'ok' : claude.state === 'none' ? 'none' : 'other',
      title: CLAUDE_TITLES[claude.state] || CLAUDE_TITLES.other,
      name: connected ? claude.name || '' : '',
      key: connected ? (claude.key || '') + (claude.models ? ` · ${claude.models} 个模型` : '') : '',
    };
  }
  const status = state.status || { state: 'none' };
  const connected = status.state === 'usegoodai';
  if (status.state === 'none' && state.status && !status.appInstalled) {
    return { state: 'none', title: '没检测到 Codex 软件', name: '', key: '先装好 ChatGPT（含 Codex），再回来点一键连接', download: true };
  }
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
  $('get-app').hidden = !card.download;
  $('status-key').classList.toggle('hint', Boolean(card.download));
}

// Keep the name and purpose stable while the status changes.
function renderEntries() {
  const image = state.image || { state: 'none' };
  const imageStates = {
    ready: '已安装',
    outdated: '可更新',
    nokey: '缺少画图密钥',
    unmanaged: '版本待确认',
  };
  $('go-image-state').textContent = image.updateAvailable ? '可更新' : imageStates[image.state] || '未安装';
  $('go-image').dataset.state = image.state === 'ready' && !image.updateAvailable ? 'done' : image.state === 'none' ? '' : 'attention';

  const models = state.models || { state: 'none' };
  const modelsStates = { active: '已导入', inactive: '需重新导入' };
  $('go-models-state').textContent = modelsStates[models.state] || '未导入';
  $('go-models').dataset.state = models.state === 'active' ? 'done' : models.state === 'inactive' ? 'attention' : '';

  // The image tool and the domestic models belong to Codex, so the Claude
  // page shows none of the entries.
  $('tools').hidden = tool === 'claude';
  $('tools-group').hidden = tool === 'claude';
  $('go-codex').hidden = tool === 'codex' || tool === 'claude';
  for (const name of ['image', 'models']) {
    $(`go-${name}`).hidden = name === tool;
  }
  for (const name of ['codex', 'claude']) {
    const pressed = name === 'claude' ? tool === 'claude' : tool !== 'claude';
    $(`tab-${name}`).setAttribute('aria-pressed', String(pressed));
  }
}

// Updating software never requires a key. Pasting a new key explicitly
// chooses the separate install/key-replacement action.
function savedImageKey() {
  const image = state.image;
  return Boolean(image && image.key && (image.state === 'ready' || image.state === 'outdated'));
}

function installedImage() {
  const image = state.image;
  return Boolean(image && image.version && ['ready', 'outdated', 'nokey'].includes(image.state));
}

function usesImageUpdate() {
  return tool === 'image' && installedImage() && keyInput.value.trim() === '';
}

function newerImageInstalled() {
  const image = state.image;
  return installedImage() && image.bundled && image.version !== image.bundled && !image.updateAvailable;
}

function imageGuide() {
  if (!installedImage()) return TOOLS.image.guide;
  const image = state.image;
  if (newerImageInstalled()) return `本机 V${image.version} 比助手内置的 V${image.bundled} 更新，保留当前版本，不降级。`;
  const first = image.updateAvailable
    ? `已安装 V${image.version}，直接点「一键更新」升级到 V${image.bundled}。`
    : `已安装 V${image.version}，可以直接修复安装文件。`;
  return first + (savedImageKey()
    ? '已有密钥保持不变，不需要重新粘贴；要换密钥才填写新的或在网站点「一键导入」。'
    : '升级不需要 Key；画图前再填写画图分组密钥或到网站点「一键导入」。');
}

function guideFor(name) {
  return name === 'image' ? imageGuide() : TOOLS[name].guide;
}

function idleLabel() {
  if (usesImageUpdate()) {
    if (newerImageInstalled()) return `保留已安装的 V${state.image.version}`;
    return state.image.updateAvailable ? `一键更新到 V${state.image.bundled}` : '重新安装当前版本';
  }
  if (tool === 'models') {
    if (confirming === 'import') return '确认导入（会关闭 Codex）';
    return state.models && state.models.state === 'active' ? '重新导入国产模型' : TOOLS.models.button;
  }
  return TOOLS[tool].button;
}

function render() {
  renderCard();
  renderEntries();
  const page = TOOLS[tool];
  $('page-intro').hidden = !page.title;
  if (page.title) {
    $('page-title').textContent = page.title;
    $('page-steps').textContent = page.steps;
  }
  if (!busy) $('connect-label').textContent = idleLabel();
  keyInput.placeholder = tool === 'image' && savedImageKey() ? '已有密钥；要换密钥才粘贴新的' : TOOLS[tool].placeholder || '';
  connectButton.classList.toggle('confirm', confirming === 'import');
  removeButton.hidden = tool !== 'models' || !state.models || state.models.state === 'none';
  removeButton.textContent = confirming === 'remove' ? '确认移除（会关闭 Codex）' : '移除国产模型';
  $('restore-anchor').hidden = tool !== 'codex' && tool !== 'claude';
  if (TOOLS[tool].restoreTip) $('restore-tip').textContent = TOOLS[tool].restoreTip;
}

function absorb(result) {
  if (result.status) state.status = result.status;
  if (result.image) state.image = result.image;
  if (result.models) state.models = result.models;
  if (result.claude) state.claude = result.claude;
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
  for (const button of [connectButton, restoreButton, removeButton, $('go-codex'), $('go-image'), $('go-models'),
    $('tab-codex'), $('tab-claude'), $('get-official'), $('get-group'), $('assistant-update-button'), chineseButton]) {
    button.disabled = on;
  }
  connectButton.classList.toggle('busy', on && Boolean(label));
  $('connect-label').textContent = on && label ? label : idleLabel();
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
  shell.classList.remove('activating');
  void shell.offsetWidth; // restart the sweep
  shell.classList.add('activating');
  setTimeout(() => shell.classList.remove('activating'), 950);
  render();
  if (tool === 'codex' || tool === 'claude') {
    $('notice').hidden = true;
  } else {
    const openSite = tool === 'image' && !savedImageKey() ? 'open-site' : '';
    showNotice(tool, guideFor(tool), openSite, TOOLS[tool].tag);
  }
  if ((tool === 'image' && !savedImageKey()) || tool === 'claude') keyInput.focus();
  if (tool === 'claude' || tool === 'codex') fillFromClipboard();
}

async function run(label, notice, action) {
  setBusy(true, label);
  showNotice('info', notice);
  try {
    const result = await action();
    if (tool === 'models' && result.tone !== 'error') setTool('codex');
    showResult(result);
  } catch (error) {
    showNotice('error', '操作没有完成，请再试一次。');
  } finally {
    if (!activeLink) {
      setBusy(false);
      nextLink();
    }
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
  if (usesImageUpdate()) {
    run('正在更新…', '正在更新生图程序，保留原有密钥配置…', () => bridge().UpdateImage());
    return;
  }
  if (tool === 'image') {
    run('正在安装…', '正在检查密钥能否画图…', () => bridge().InstallImage(key));
    return;
  }
  if (tool === 'claude') {
    run('正在连接…', '正在检查密钥和可用的 Claude 模型…', () => bridge().ConnectClaude(key));
    return;
  }
  run('正在连接…', '正在检查密钥…', () => bridge().Connect(key));
}

function chooseImportTarget() {
  const dialog = $('import-target');
  return new Promise((resolve) => {
    dialog.returnValue = '';
    dialog.addEventListener('close', () => resolve(dialog.returnValue), { once: true });
    dialog.showModal();
  });
}

async function importLink({ raw, imageWasOpen }) {
  let parsed;
  try {
    parsed = await bridge().ParseLink(raw);
  } catch (error) {
    showNotice('error', '操作没有完成，请再试一次。');
    return;
  }
  if (!parsed.ok) {
    showResult(parsed.result);
    return;
  }
  const target = parsed.needsTarget
    ? (imageWasOpen ? 'image' : await chooseImportTarget())
    : parsed.app;
  const name = parsed.name || '';
  switch (target) {
    case 'image': {
      setTool('image');
      const notice = name ? `正在把「${name}」导入生图工具…` : '正在把密钥导入生图工具…';
      await run('正在导入…', notice, () => bridge().ImportImage(parsed.key, name));
      break;
    }
    case 'claude': {
      setTool('claude');
      const notice = name ? `正在把「${name}」接入 Claude…` : '正在把密钥接入 Claude…';
      await run('正在连接…', notice, () => bridge().ImportClaude(parsed.key, name));
      break;
    }
    case 'codex': {
      setTool('codex');
      const notice = name ? `正在把「${name}」接入 Codex…` : '正在把密钥接入 Codex…';
      await run('正在连接…', notice, () => bridge().Import(parsed.key, name));
      break;
    }
    default:
      showNotice('info', '已取消导入密钥。');
  }
}

function enqueueLink(raw) {
  raw = raw.trim();
  if (!raw || activeLink?.raw === raw || queuedLinks.some((link) => link.raw === raw)) return;
  queuedLinks.push({ raw, imageWasOpen: tool === 'image' });
  nextLink();
}

async function nextLink() {
  if (busy || activeLink || queuedLinks.length === 0) return;
  activeLink = queuedLinks.shift();
  setBusy(true, '正在读取导入链接…');
  try {
    await importLink(activeLink);
  } finally {
    activeLink = null;
    setBusy(false);
    nextLink();
  }
}

async function fillFromClipboard() {
  // Upgrades never import clipboard credentials automatically, including
  // installations whose image key is currently missing.
  if (busy || tool === 'models' || (tool === 'image' && installedImage()) || keyInput.value.trim() !== '' || !bridge()) return;
  const asked = tool;
  try {
    const key = await bridge().ClipboardKey();
    // The window may have moved on while the clipboard was read.
    if (!key || busy || tool !== asked || keyInput.value.trim() !== '') return;
    keyInput.value = key;
    $('connect-label').textContent = idleLabel();
  } catch (error) {
    // The clipboard may be busy; the user can still paste by hand.
  }
}

// The button says whether the saved image key or the typed one is used.
keyInput.addEventListener('input', () => {
  if (!busy) $('connect-label').textContent = idleLabel();
});

$('connect-form').addEventListener('submit', (event) => {
  event.preventDefault();
  if (!busy) submit();
});

for (const name of ['codex', 'image', 'models']) {
  $(`go-${name}`).addEventListener('click', () => {
    if (!busy) setTool(name);
  });
}

for (const name of ['codex', 'claude']) {
  $(`tab-${name}`).addEventListener('click', () => {
    tabsUsed = true;
    if (!busy) setTool(name);
  });
}

// New users may not notice the two tabs, so each one pulses once: Codex 5
// seconds after opening, Claude after 20. Nothing pulses once a tab was
// clicked, while working, or for the page already open (Claude).
const TAB_HINTS = [['codex', 5000], ['claude', 20000]];
let tabsUsed = false;

function hintTab(name) {
  if (tabsUsed || busy || (name === 'claude' && tool === 'claude') || (name === 'codex' && tool !== 'codex')) return;
  const tab = $(`tab-${name}`);
  tab.classList.remove('hint');
  void tab.offsetWidth;
  tab.classList.add('hint');
  tab.addEventListener('animationend', () => tab.classList.remove('hint'), { once: true });
}

$('get-official').addEventListener('click', () => bridge().OpenDownload(tool === 'claude' ? 'claude' : 'codex'));

// The QQ group's files carry both installers, for anyone who cannot reach
// the official sites.
$('get-group').addEventListener('click', () => {
  const qq = $('qq');
  qq.classList.remove('flash');
  void qq.offsetWidth;
  qq.classList.add('flash');
  const app = tool === 'claude' ? 'Claude' : 'ChatGPT';
  showNotice('info', `打不开官网时，进 QQ 群在「群文件」里下载 ${app} 安装包：点下方「加入群聊」，或复制群号 ${$('version').dataset.qq || '1020015031'} 搜索加群。`);
});

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
  if (busy) return;
  if (tool === 'claude') run('正在恢复…', '正在恢复 Claude 官方登录…', () => bridge().RestoreClaude());
  else run('正在恢复…', '正在恢复官方登录…', () => bridge().Restore());
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
chineseButton.addEventListener('click', async () => {
  if (busy) return;
  cancelConfirm();
  render();
  setBusy(true);
  chineseButton.textContent = '正在中文化…';
  showNotice('info', '正在打开 PowerShell，请在该窗口查看完整过程。');
  try {
    showResult(await bridge().RunChinese());
  } catch {
    showNotice('error', '中文化未完成，请查看 PowerShell 窗口和运行记录。');
  } finally {
    chineseButton.textContent = '一键中文化（没有梯子才需要）';
    setBusy(false);
    nextLink();
  }
});
$('join-qq').addEventListener('click', () => bridge().JoinGroup());
$('open-site').addEventListener('click', () => bridge().OpenSite());
$('open-api-keys').addEventListener('click', () => bridge().OpenAPIKeys());

async function checkAssistantUpdate(app) {
  try {
    const version = await app.CheckAssistantUpdate();
    if (!version) return;
    $('assistant-update-message').textContent = `Windows 助手可更新到 ${version}`;
    $('assistant-update').hidden = false;
  } catch {
    // A missing or unreachable release must never interrupt setup.
  }
}

$('assistant-update-button').addEventListener('click', async () => {
  if (busy) return;
  const message = $('assistant-update-message');
  const button = $('assistant-update-button');
  let restarting = false;
  setBusy(true, '正在更新助手…');
  try {
    if (!assistantUpdateDownloaded) {
      message.textContent = '正在下载并校验 Windows 助手…';
      const error = await bridge().DownloadAssistantUpdate();
      if (error) throw new Error(error);
      assistantUpdateDownloaded = true;
    }
    if (queuedLinks.length) {
      message.textContent = '新版已下载。导入完成后可以重启更新。';
      button.textContent = '重启更新';
      return;
    }
    message.textContent = '正在重启 Windows 助手…';
    const error = await bridge().RestartAssistantUpdate();
    if (error) throw new Error(error);
    restarting = true;
  } catch (error) {
    assistantUpdateDownloaded = false;
    message.textContent = error.message || '助手更新失败，可以稍后重试。';
    button.textContent = '重试更新';
  } finally {
    if (!restarting) {
      setBusy(false);
      nextLink();
    }
  }
});

window.addEventListener('focus', fillFromClipboard);
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') fillFromClipboard();
});

(async function start() {
  const app = await waitForBridge();
  if (!app) return;
  const info = await app.Info();
  $('version').textContent = info.version;
  $('version').dataset.qq = info.qq;
  state.status = await app.Status();
  state.image = await app.ImageStatus();
  state.models = await app.ModelsStatus();
  state.claude = await app.ClaudeStatus();
  render();
  for (const [name, delay] of TAB_HINTS) setTimeout(() => hintTab(name), delay);
  let earlyEvents = [];
  window.runtime.EventsOn('import-link', (raw) => {
    if (earlyEvents) earlyEvents.push(raw);
    else enqueueLink(raw);
  });
  const links = [...(await app.TakeLaunchLinks() || []), ...earlyEvents];
  earlyEvents = null;
  if (links.length > 0) {
    links.forEach(enqueueLink);
  } else {
    fillFromClipboard();
  }
  void checkAssistantUpdate(app);
})();
