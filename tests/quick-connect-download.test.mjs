import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
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
  const runner = entries.get(`${contents}Resources/run.command`).body
  assert.deepEqual(runner, await readFile(new URL('usegoodai-codex-installer/quick-connect/macapp/run.command', root)))
  assert.match(runner.toString('utf8'), /USEGOODAI_KEY="\$key" \/bin\/bash "\$resource_dir\/install\.sh"\n/)
  const plist = entries.get(`${contents}Info.plist`).body.toString('utf8')
  assert.match(plist, /<string>UseGoodAI中转快速接入助手<\/string>/)
  // The website's one import button opens usegoodai:// links on Mac too.
  assert.match(plist, /<key>CFBundleURLSchemes<\/key>\s*<array>\s*<string>usegoodai<\/string>\s*<\/array>/)
  const launcher = entries.get(`${contents}MacOS/launcher`)
  assert.equal(launcher.body.readUInt32LE(0), 0xfeedfacf)
  assert.equal(launcher.body.readUInt32LE(4), 0x0100000c)
  assert.ok(launcher.body.includes(Buffer.from('usegoodai-quick-connect/macapp')), 'link-aware launcher')
  for (const name of ['MacOS/launcher', 'Resources/install.sh', 'Resources/run.command']) {
    assert.equal(entries.get(contents + name).mode & 0o111, 0o111, `${name} is executable`)
  }
})

test('tool-set download keeps Windows in one GUI and bundles the current image tool', async () => {
  const rules = await headerRules()
  const headers = rules.get('/download/usegoodai-tools.zip')
  assert.ok(headers.includes('Content-Type: application/zip'))
  const disposition = headers.find((line) => /^content-disposition:/i.test(line))
  const filename = decodeURIComponent(disposition.match(/filename\*=UTF-8''([^;\s]+)/)[1])
  assert.match(filename, /^中转站快速导入工具_\d{8}-\d{4}\.zip$/)

  const data = await readFile(new URL('docs/public/download/usegoodai-tools.zip', root))
  assert.ok(data.length <= limit, `${data.length} bytes`)
  const entries = readZip(data)
  const windowsFiles = [...entries.keys()].filter((name) => name.startsWith('Windows-x64/') && !name.endsWith('/'))
  assert.deepEqual(windowsFiles, [`Windows-x64/1.${product}.exe`])
  const window = entries.get(windowsFiles[0]).body
  assert.deepEqual(window, await readFile(new URL(`docs/public/download/${exeName}`, root)))
  const release = 'docs/public/install/usegoodai-imagines-tool/releases/v0.9.2/'
  const nativeWindows = await readFile(new URL(`${release}usegoodai-imagines-tool-v0.9.2-windows-amd64.exe`, root))
  assert.ok(window.includes(nativeWindows), 'the single Windows GUI embeds the current native image tool')

  const macApps = [...new Set([...entries.keys()].flatMap((name) => {
    const match = name.match(/^Mac-Apple芯片\/([^/]+\.app)\//)
    return match ? [match[1]] : []
  }))].sort()
  assert.deepEqual(macApps, [`1.${product}.app`, '2.UseGoodAI生图工具.app', '3.Codex国产模型导入.app'].sort())
  assert.deepEqual(
    entries.get(`Mac-Apple芯片/1.${product}.app/Contents/Resources/install.sh`).body,
    await readFile(new URL('docs/public/install/codex.sh', root)),
    'the bundled Mac assistant runs the published installer',
  )
  const nativeMac = await readFile(new URL(`${release}usegoodai-imagines-tool-v0.9.2-darwin-arm64`, root))
  assert.deepEqual(entries.get('Mac-Apple芯片/2.UseGoodAI生图工具.app/Contents/Resources/tool').body, nativeMac)
  for (const app of macApps) {
    assert.equal(entries.get(`Mac-Apple芯片/${app}/Contents/MacOS/launcher`).mode & 0o111, 0o111)
  }
  assert.match(entries.get('使用说明.txt').body.toString('utf8'), /V0\.9\.2/)
  assert.ok(![...entries.keys()].some((name) => /SHA256SUMS|来源记录/.test(name)))
})

test('previous stable tool set and helper stay downloadable beside the current ones', async () => {
  const rules = await headerRules()
  const attachment = (path) => {
    const lines = rules.get(path)
    assert.ok(lines, path)
    const disposition = lines.find((line) => /^content-disposition:/i.test(line))
    return decodeURIComponent(disposition.match(/filename\*=UTF-8''([^;\s]+)/)[1])
  }
  assert.ok(rules.get('/download/previous/usegoodai-tools.zip').includes('Content-Type: application/zip'))
  const zipFile = attachment('/download/previous/usegoodai-tools.zip')
  const stamp = zipFile.match(/^中转站快速导入工具_(\d{8}-\d{4})\.zip$/)?.[1]
  assert.ok(stamp, zipFile)
  assert.notEqual(zipFile, attachment('/download/usegoodai-tools.zip'))
  assert.equal(attachment(`/download/previous/${exeName}`), `${product}_${stamp}.exe`)

  const data = await readFile(new URL('docs/public/download/previous/usegoodai-tools.zip', root))
  assert.ok(data.length <= limit, `${data.length} bytes`)
  const entries = readZip(data)
  const window = entries.get(`Windows-x64/1.${product}.exe`).body
  assert.deepEqual(window, await readFile(new URL(`docs/public/download/previous/${exeName}`, root)))
  // The previous stable set is the 20261105-1538 build with image tool
  // V0.9.0. V0.9.0's release folder has left the site, so the files are
  // known by their SHA-256 (the Mac tool's is in V0.9.0's SHA256SUMS).
  const sha256 = (body) => createHash('sha256').update(body).digest('hex')
  assert.equal(sha256(window), '331bf0c7a7d1fe7052b2db2fbd6921dec75a59c8c5df1038d87bc63afc604630')
  assert.equal(
    sha256(entries.get('Mac-Apple芯片/2.UseGoodAI生图工具.app/Contents/Resources/tool').body),
    '9e0b73b893ee97a1c9926cb688f197b24a4f1584423f1bbae6010d0d806fd34f',
  )
  assert.match(entries.get('使用说明.txt').body.toString('utf8'), /V0\.9\.0/)
})


test('Mac domestic model app contains the current published installer', async () => {
  const archive = await readFile(new URL('docs/public/download/usegoodai-tools.zip', root))
  const entries = readZip(archive)
  const path = 'Mac-Apple芯片/3.Codex国产模型导入.app/Contents/Resources/install.sh'
  assert.deepEqual(entries.get(path).body, await readFile(new URL('docs/public/install/codex-models.sh', root)))
  assert.equal(entries.get(path).mode & 0o111, 0o111)
})
