'use strict';

const $ = (id) => document.getElementById(id);
const keyInput = $('key');
const connectButton = $('connect');
const restoreButton = $('restore');
const STATUS_TITLES = {
  usegoodai: '已连接 UseGoodAI',
  none: '还没连接',
  other: '当前用的是官方登录或其他服务',
};

let busy = false;
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

function renderStatus(status) {
  if (!status) return;
  const card = $('status');
  card.dataset.state = status.state;
  $('status-title').textContent = STATUS_TITLES[status.state] || STATUS_TITLES.other;
  $('status-key').textContent = status.state === 'usegoodai' ? status.key || '' : '';
}

function showNotice(tone, text) {
  const notice = $('notice');
  notice.dataset.tone = tone;
  $('notice-text').textContent = text;
  notice.hidden = false;
}

function showResult(result) {
  renderStatus(result.status);
  showNotice(result.tone, result.message);
}

function setBusy(on, label) {
  busy = on;
  connectButton.disabled = on;
  restoreButton.disabled = on;
  connectButton.classList.toggle('busy', on);
  $('connect-label').textContent = on ? label : '一键连接 Codex';
}

async function run(label, notice, action) {
  setBusy(true, label);
  showNotice('info', notice);
  try {
    showResult(await action());
  } catch (error) {
    showNotice('error', '操作没有完成，请再试一次。');
  } finally {
    setBusy(false);
    nextLink();
  }
}

function connect(key, notice) {
  return run('正在连接…', notice || '正在检查密钥…', () => bridge().Connect(key));
}

// Links import straight away, without asking: check, write, close Codex.
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
  keyInput.value = parsed.key;
  await connect(parsed.key, parsed.name ? `正在导入「${parsed.name}」…` : '正在导入密钥…');
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
  if (busy || keyInput.value.trim() !== '' || !bridge()) return;
  try {
    const key = await bridge().ClipboardKey();
    if (key && keyInput.value.trim() === '') keyInput.value = key;
  } catch (error) {
    // The clipboard may be busy; the user can still paste by hand.
  }
}

$('connect-form').addEventListener('submit', (event) => {
  event.preventDefault();
  if (!busy) connect(keyInput.value);
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
  renderStatus(await app.Status());
  window.runtime.EventsOn('import-link', enqueueLink);
  const link = await app.TakeLaunchLink();
  if (link) {
    enqueueLink(link);
  } else {
    fillFromClipboard();
  }
})();
