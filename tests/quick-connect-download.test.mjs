import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'
import { inflateRawSync } from 'node:zlib'

const root = new URL('../', import.meta.url)
const limit = 25 * 1024 * 1024
const exeName = 'usegoodai-quick-connect-windows-x64.exe'
const zipName = 'usegoodai-quick-connect-mac-arm64.zip'
const product = 'UseGoodAI中转快速接入助手'

async function headerRules() {
  const text = await readFile(new URL('docs/public/_headers', root), 'utf8')
  const rules = new Map()
  let current
  for (const line of text.split('\n')) {
    if (!line.trim() || line.trimStart().startsWith('#')) continue
    if (!/^\s/.test(line)) {
      current = []
      rules.set(line.trim(), current)
    } else {
      current.push(line.trim())
    }
  }
  return rules
}

function readZip(data) {
  let end = data.length - 22
  while (end >= 0 && data.readUInt32LE(end) !== 0x06054b50) end--
  assert.ok(end >= 0, 'zip end record')
  const count = data.readUInt16LE(end + 10)
  let offset = data.readUInt32LE(end + 16)
  const entries = new Map()
  for (let i = 0; i < count; i++) {
    assert.equal(data.readUInt32LE(offset), 0x02014b50)
    const flags = data.readUInt16LE(offset + 8)
    const method = data.readUInt16LE(offset + 10)
    const compressedSize = data.readUInt32LE(offset + 20)
    const nameLength = data.readUInt16LE(offset + 28)
    const extraLength = data.readUInt16LE(offset + 30)
    const commentLength = data.readUInt16LE(offset + 32)
    const mode = data.readUInt32LE(offset + 38) >>> 16
    const local = data.readUInt32LE(offset + 42)
    const name = data.subarray(offset + 46, offset + 46 + nameLength).toString('utf8')
    const start = local + 30 + data.readUInt16LE(local + 26) + data.readUInt16LE(local + 28)
    const stored = data.subarray(start, start + compressedSize)
    entries.set(name, { flags, mode, body: method === 8 ? inflateRawSync(stored) : stored })
    offset += 46 + nameLength + extraLength + commentLength
  }
  return entries
}

test('download files carry Chinese attachment names without a duplicated Content-Disposition', async () => {
  const rules = await headerRules()
  const all = rules.get('/download/*')
  assert.ok(all, '/download/* rule')
  assert.ok(all.includes('Cache-Control: public, max-age=0, must-revalidate'))
  // Cloudflare joins the same header from two matching rules with a comma, so the
  // folder rule must not set Content-Disposition next to the per-file rules.
  assert.ok(!all.some((line) => /^content-disposition:/i.test(line)))
  for (const [file, extension] of [[exeName, 'exe'], [zipName, 'zip']]) {
    const lines = rules.get(`/download/${file}`)
    assert.ok(lines, file)
    const disposition = lines.find((line) => /^content-disposition:/i.test(line))
    assert.match(disposition, /^Content-Disposition: attachment;/)
    const encoded = disposition.match(/filename\*=UTF-8''([^;\s]+)/)[1]
    assert.equal(decodeURIComponent(encoded), `${product}.${extension}`)
  }
})

test('Windows download is the x64 GUI helper under 25 MiB', async () => {
  const data = await readFile(new URL(`docs/public/download/${exeName}`, root))
  assert.ok(data.length <= limit, `${data.length} bytes`)
  assert.equal(data.subarray(0, 2).toString('latin1'), 'MZ')
  const pe = data.readUInt32LE(0x3c)
  assert.equal(data.subarray(pe, pe + 4).toString('latin1'), 'PE\0\0')
  assert.equal(data.readUInt16LE(pe + 4), 0x8664)
  assert.equal(data.readUInt16LE(pe + 24 + 68), 2)
  assert.ok(data.includes(Buffer.from(product, 'utf16le')), 'version resource names the product')
})

test('Mac download is the zipped app with the published codex.sh', async () => {
  const data = await readFile(new URL(`docs/public/download/${zipName}`, root))
  assert.ok(data.length <= limit, `${data.length} bytes`)
  const entries = readZip(data)
  const prefix = `${product}.app/`
  for (const [name, entry] of entries) {
    assert.ok(name.startsWith(prefix), name)
    assert.ok(entry.flags & 0x800, `${name} is stored as UTF-8`)
  }
  const contents = `${prefix}Contents/`
  const installer = await readFile(new URL('docs/public/install/codex.sh', root))
  assert.deepEqual(entries.get(`${contents}Resources/install.sh`).body, installer)
  assert.match(entries.get(`${contents}Resources/run.command`).body.toString('utf8'), /install\.sh" --from-app\n/)
  assert.match(entries.get(`${contents}Info.plist`).body.toString('utf8'), /<string>UseGoodAI中转快速接入助手<\/string>/)
  const launcher = entries.get(`${contents}MacOS/launcher`)
  assert.equal(launcher.body.readUInt32LE(0), 0xfeedfacf)
  assert.equal(launcher.body.readUInt32LE(4), 0x0100000c)
  for (const name of ['MacOS/launcher', 'Resources/install.sh', 'Resources/run.command']) {
    assert.equal(entries.get(contents + name).mode & 0o111, 0o111, `${name} is executable`)
  }
})
