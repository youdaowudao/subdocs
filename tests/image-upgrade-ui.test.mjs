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
