import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import vm from 'node:vm'

const source = readFileSync(new URL('../usegoodai-codex-installer/quick-connect/frontend/app.js', import.meta.url), 'utf8')

function imagePanel(image, key = '') {
  const elements = new Map()
  const element = (id) => {
    if (!elements.has(id)) elements.set(id, {
      textContent: '', value: '', dataset: {}, style: {}, hidden: false, disabled: false,
      classList: { add() {}, remove() {}, toggle() {} },
      handlers: {}, addEventListener(name, handler) { this.handlers[name] = handler },
      setAttribute() {}, focus() {}, prepend() {},
    })
    return elements.get(id)
  }
  const calls = []
  const window = { addEventListener() {} }
  const context = vm.createContext({
    window, document: { getElementById: element, createElement: () => element('created'), addEventListener() {} },
    setTimeout: () => 0, clearTimeout() {}, console,
  })
  vm.runInContext(source, context)
  // Startup is waiting for the bridge. Exercise the real rendered image panel.
  window.go = { main: { App: {
    UpdateImage: async () => { calls.push('update'); return { tone: 'success', message: 'updated' } },
    InstallImage: async (input) => { calls.push(['install', input]); return { tone: 'success', message: 'installed' } },
  } } }
  vm.runInContext(`tool = 'image'; state.image = ${JSON.stringify(image)}; keyInput.value = ${JSON.stringify(key)}; render();`, context)
  return { context, element, calls }
}

test('shows the installed old version and the update button even without a key', async () => {
  for (const key of ['', 'sk-****-masked']) {
    const panel = imagePanel({ state: key ? 'outdated' : 'nokey', version: '0.9.1', bundled: '0.9.6', updateAvailable: true, key })
    assert.equal(panel.element('connect-label').textContent, '一键更新到 V0.9.6')
    assert.equal(vm.runInContext('cardFor().title', panel.context).includes('V0.9.1 已安装，可更新到 V0.9.6'), true)
    assert.equal(vm.runInContext('imageGuide()', panel.context).includes(key ? '不需要重新粘贴' : '升级不需要 Key'), true)
    let clipboardReads = 0
    panel.context.window.go.main.App.ClipboardKey = async () => { clipboardReads += 1; return 'synthetic-unrelated-key' }
    await vm.runInContext('fillFromClipboard()', panel.context)
    assert.equal(clipboardReads, 0)
    vm.runInContext('submit()', panel.context)
    await new Promise((resolve) => setImmediate(resolve))
    assert.deepEqual(panel.calls, ['update'])
  }
})

test('pasting a replacement key uses key validation and installation explicitly', async () => {
  const panel = imagePanel({ state: 'outdated', version: '0.9.1', bundled: '0.9.6', updateAvailable: true, key: 'masked' }, 'synthetic-replacement-key')
  assert.equal(panel.element('connect-label').textContent, '一键导入生图工具')
  vm.runInContext('submit()', panel.context)
  await new Promise((resolve) => setImmediate(resolve))
  assert.deepEqual(panel.calls, [['install', 'synthetic-replacement-key']])
})

test('an installed newer version is shown as preserved instead of offered a downgrade', () => {
  const panel = imagePanel({ state: 'ready', version: '0.10.0', bundled: '0.9.6', key: 'masked' })
  assert.equal(panel.element('connect-label').textContent, '保留已安装的 V0.10.0')
  assert.equal(vm.runInContext('imageGuide()', panel.context).includes('不降级'), true)
})

test('Codex and Claude show the website import guide above the manual fallback', () => {
  const panel = imagePanel({ state: 'outdated', updateAvailable: true });
  const run = (code) => vm.runInContext(code, panel.context);
  run("state.models = { state: 'inactive' }; setTool('codex')");
  assert.equal(panel.element('page-title').textContent, '将 Codex 接入 UseGoodAI');
  assert.match(panel.element('page-steps').textContent, /编程分组.*一键导入 Codex/);
  assert.equal(panel.element('go-image-state').textContent, '可更新');
  assert.equal(panel.element('go-models-state').textContent, '需重新导入');
  assert.equal(panel.element('tools').hidden, false);

  run("setTool('claude')");
  assert.equal(panel.element('page-title').textContent, '将 Claude 桌面版接入 UseGoodAI');
  assert.match(panel.element('page-steps').textContent, /Claude 分组.*一键导入 Claude/);
  assert.equal(panel.element('tools').hidden, true);

  run("setTool('image')");
  assert.equal(panel.element('page-intro').hidden, true);
})

test('Antigravity download guidance reflects App detection, not connection status; no model count', async () => {
  const panel = imagePanel({ state: 'none' });
  const run = (code) => vm.runInContext(code, panel.context);
  const app = panel.context.window.go.main.App;
  run("tool = 'antigravity'; state.antigravity = null; render()");
  assert.equal(panel.element('get-app').hidden, true);
  assert.match(panel.element('status-title').textContent, /正在检测/);
  app.AntigravityStatus = async () => ({ state: 'none', appDetected: true });
  await run('refreshAntigravityStatus()');
  assert.equal(panel.element('get-app').hidden, true);
  assert.equal(panel.element('status-title').textContent, '还没连接');
  assert.match(panel.element('status-key').textContent, /已检测到/);
  app.AntigravityStatus = async () => ({ state: 'none', appDetected: false });
  await run('refreshAntigravityStatus()');
  assert.equal(panel.element('get-app').hidden, false);
  assert.equal(panel.element('status-title').textContent, '未检测到 Antigravity App 或 CLI');
  assert.match(panel.element('status-key').textContent, /已安装可直接连接/);
  app.AntigravityStatus = async () => ({ state: 'none', appDetected: false, cliDetected: true });
  await run('refreshAntigravityStatus()');
  assert.equal(panel.element('get-app').hidden, true);
  assert.match(panel.element('status-key').textContent, /已检测到 Antigravity CLI/);
  app.AntigravityStatus = async () => ({ state: 'usegoodai', appDetected: true, key: 'sk-masked', models: 20 });
  await run('refreshAntigravityStatus()');
  assert.equal(panel.element('get-app').hidden, true);
  assert.equal(panel.element('status-key').textContent, 'sk-masked');
  assert.equal(panel.element('status-title').textContent, '已保存 UseGoodAI 配置');
});

test('the assistant checks silently and asks before downloading a new Windows version', async () => {
  const panel = imagePanel({ state: 'none' })
  const run = (code) => vm.runInContext(code, panel.context)
  const app = panel.context.window.go.main.App
  const banner = panel.element('assistant-update')
  const message = panel.element('assistant-update-message')
  const button = panel.element('assistant-update-button')
  banner.hidden = true
  app.CheckAssistantUpdate = async () => { throw new Error('offline') }
  await run('checkAssistantUpdate(bridge())')
  assert.equal(banner.hidden, true)

  app.CheckAssistantUpdate = async () => '1.1.23'
  app.DownloadAssistantUpdate = async () => { panel.calls.push('download'); return '校验失败' }
  app.RestartAssistantUpdate = async () => { panel.calls.push('restart'); return '' }
  await run('checkAssistantUpdate(bridge())')
  assert.equal(banner.hidden, false)
  assert.match(message.textContent, /1\.1\.23/)
  assert.deepEqual(panel.calls, [])
  await button.handlers.click()
  assert.deepEqual(panel.calls, ['download'])
  assert.equal(button.textContent, '重试更新')
  assert.equal(button.disabled, false)

  app.DownloadAssistantUpdate = async () => { panel.calls.push('download'); return '' }
  await button.handlers.click()
  assert.deepEqual(panel.calls, ['download', 'download', 'restart'])
})

test('website image import stays on the image page and merges clicks in progress', async () => {
  const panel = imagePanel({ state: 'none' })
  const run = (code) => vm.runInContext(code, panel.context)
  const app = panel.context.window.go.main.App
  const wait = () => new Promise((resolve) => setImmediate(resolve))
  let release
  const codexAuth = { key: 'sk-codex-fixture' }
  let imageKey
  app.ParseLink = async () => ({ ok: true, app: 'image', key: 'sk-image-fixture' })
  app.Import = async (key) => { codexAuth.key = key }
  app.ImportImage = async (key) => {
    panel.calls.push('image')
    await new Promise((resolve) => { release = resolve })
    imageKey = key
    return { tone: 'success', message: '画图密钥已导入', image: { state: 'ready', version: '0.9.6', key: 'masked' } }
  }
  run("setTool('codex'); enqueueLink('image-link'); enqueueLink('image-link')")
  await wait()
  assert.deepEqual(panel.calls, ['image'])
  run("enqueueLink('image-link')")
  release()
  await wait()
  assert.deepEqual(panel.calls, ['image'])
  assert.equal(run('tool'), 'image')
  assert.equal(panel.element('notice-text').textContent, '画图密钥已导入')
  assert.equal(panel.element('status-title').textContent, 'V0.9.6 已安装')
  assert.equal(imageKey, 'sk-image-fixture')
  assert.equal(codexAuth.key, 'sk-codex-fixture')

  run("enqueueLink('image-link')")
  await wait()
  release()
  await wait()
  assert.deepEqual(panel.calls, ['image', 'image'])
  assert.equal(run('tool'), 'image')
  assert.equal(codexAuth.key, 'sk-codex-fixture')
})

test('legacy imports choose before writing unless received on the image page', async () => {
  const panel = imagePanel({ state: 'none' })
  const run = (code) => vm.runInContext(code, panel.context)
  const app = panel.context.window.go.main.App
  const wait = () => new Promise((resolve) => setImmediate(resolve))
  let choose
  panel.context.selectLegacyTarget = () => new Promise((resolve) => { choose = resolve })
  run('chooseImportTarget = selectLegacyTarget')
  app.ParseLink = async () => ({ ok: true, app: 'codex', needsTarget: true, key: 'sk-image-fixture' })
  app.Import = async () => { panel.calls.push('codex') }
  app.ImportImage = async () => {
    panel.calls.push('image')
    return { tone: 'error', message: '这把密钥不能画图。' }
  }
  run("setTool('codex'); enqueueLink('old-link')")
  await wait()
  assert.deepEqual(panel.calls, [])
  choose('')
  await wait()
  assert.deepEqual(panel.calls, [])

  run("enqueueLink('old-link')")
  await wait()
  choose('image')
  await wait()
  assert.deepEqual(panel.calls, ['image'])
  assert.equal(panel.element('notice-text').textContent, '这把密钥不能画图。')
  assert.equal(run('tool'), 'image')

  run("setBusy(true, '正在更新…'); enqueueLink('old-link'); setTool('codex'); setBusy(false); nextLink()")
  await wait()
  assert.deepEqual(panel.calls, ['image', 'image'])
  assert.equal(run('tool'), 'image')
})

for (const [target, method] of [['codex', 'Import'], ['claude', 'ImportClaude']]) {
  test(`an explicit ${target} link switches from the image page before starting its import`, async () => {
    const panel = imagePanel({ state: 'ready', version: '0.9.6', key: 'masked' })
    const app = panel.context.window.go.main.App
    const key = `sk-${target}-fixture`
    const result = { tone: 'success', message: '密钥已导入' }
    let finish
    app.ParseLink = async () => ({ ok: true, app: target, key })
    app[method] = async (input) => {
      panel.calls.push([target, input, vm.runInContext('tool', panel.context)])
      return new Promise((resolve) => { finish = resolve })
    }
    app.ImportImage = async () => { panel.calls.push('image') }

    vm.runInContext("enqueueLink('explicit-target')", panel.context)
    await new Promise((resolve) => setImmediate(resolve))
    assert.deepEqual(panel.calls, [[target, key, target]])
    finish(result)
    await new Promise((resolve) => setImmediate(resolve))
    assert.equal(vm.runInContext('tool', panel.context), target)
    assert.equal(panel.element('notice-text').textContent, result.message)
  })
}
