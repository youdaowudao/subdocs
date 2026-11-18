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
      addEventListener() {}, setAttribute() {}, focus() {}, prepend() {},
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

test('an explicit Codex link received on the image page uses the Codex importer', async () => {
  const panel = imagePanel({ state: 'ready', version: '0.9.6', key: 'masked' })
  const app = panel.context.window.go.main.App
  app.ParseLink = async () => ({ ok: true, app: 'codex', key: 'sk-codex-fixture' })
  app.Import = async (key) => {
    panel.calls.push(['codex', key])
    return { tone: 'success', message: 'Codex 已连接' }
  }
  app.ImportImage = async () => { panel.calls.push('image') }
  vm.runInContext("enqueueLink('explicit-codex')", panel.context)
  await new Promise((resolve) => setImmediate(resolve))
  assert.deepEqual(panel.calls, [['codex', 'sk-codex-fixture']])
  assert.equal(vm.runInContext('tool', panel.context), 'image')
})
