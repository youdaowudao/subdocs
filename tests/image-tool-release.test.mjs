import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile, readdir } from 'node:fs/promises'
import test from 'node:test'

const publicRoot = new URL('../docs/public/', import.meta.url)
const releaseRoot = new URL(
  'install/usegoodai-imagines-tool/releases/v0.7.6/',
  publicRoot,
)
const artifactNames = [
  'usegoodai-imagines-tool-v0.7.6-windows-amd64.exe',
  'usegoodai-imagines-tool-v0.7.6-darwin-arm64',
  'usegoodai-imagines-tool-v0.7.6-darwin-amd64',
]
const shellUrl = new URL('install/usegoodai-imagines-tool/install.sh', publicRoot)
const powershellUrl = new URL('install/usegoodai-imagines-tool/install.ps1', publicRoot)
const checksumUrl = new URL('SHA256SUMS', releaseRoot)
const headersUrl = new URL('_headers', publicRoot)
const entryRoot = new URL('install/usegoodai-imagines-tool/', publicRoot)
const releasesRoot = new URL('install/usegoodai-imagines-tool/releases/', publicRoot)

function parseChecksums(text) {
  return new Map(
    text.trim().split('\n').map((line) => {
      const match = line.match(/^([0-9a-f]{64})\s{2}(.+)$/)
      assert.ok(match, `invalid checksum line: ${line}`)
      return [match[2], match[1]]
    }),
  )
}

test('publishes matching V0.7.6 native artifacts, scripts and checksums', async () => {
  assert.deepEqual((await readdir(releaseRoot)).sort(), ['SHA256SUMS', ...artifactNames].sort())
  assert.deepEqual((await readdir(entryRoot)).sort(), ['install.ps1', 'install.sh', 'releases'])
  assert.deepEqual(
    (await readdir(releasesRoot)).sort(),
    ['v0.7.2', 'v0.7.3', 'v0.7.4', 'v0.7.5', 'v0.7.6'],
  )
  const [shell, powershell, checksum, ...artifacts] = await Promise.all([
    readFile(shellUrl, 'utf8'),
    readFile(powershellUrl, 'utf8'),
    readFile(checksumUrl, 'utf8'),
    ...artifactNames.map((name) => readFile(new URL(name, releaseRoot))),
  ])
  const checksums = parseChecksums(checksum)
  assert.equal(checksums.size, artifactNames.length)

  for (const [index, name] of artifactNames.entries()) {
    const digest = createHash('sha256').update(artifacts[index]).digest('hex')
    assert.equal(checksums.get(name), digest)
    const installScript = name.includes('windows') ? powershell : shell
    assert.match(installScript, new RegExp(digest))
  }
  for (const script of [shell, powershell]) {
    assert.match(script, /releases\/v0\.7\.6/)
    assert.doesNotMatch(script, /python|Expand-Archive|v0\.2-r1\.zip/i)
  }
  for (const script of [powershell]) {
    assert.match(script, /if\s*\(\$Architecture.*?-ne\s*"AMD64"\).*?throw\s*\(/s)
    assert.match(script, /catch\s*\{\s*throw\s*\(/s)
    assert.doesNotMatch(script, /^\s*exit\b/im)
    assert.match(script, /Download-WithPercent/)
    assert.match(script, /Write-Progress/)
    assert.match(script, /-PercentComplete\s+\$Percent/)
    assert.doesNotMatch(script, /Invoke-WebRequest/)
  }
  const combined = [shell, powershell].join('\n')
  assert.match(combined, /darwin-amd64/)
  assert.match(shell, /Darwin\/x86_64/)
  assert.match(shell, /sysctl\.proc_translated/)
  assert.match(shell, /expected_macho_architecture/)
  assert.doesNotMatch(combined, /windows-arm64|linux-amd64|linux-arm64/)
})

test('publishes explicit content types and cache policy', async () => {
  const headers = await readFile(headersUrl, 'utf8')

  for (const name of ['install.ps1', 'install.sh']) {
    assert.match(
      headers,
      new RegExp(`/install/usegoodai-imagines-tool/${name.replace('.', '\\.')}` +
        '\\s+Content-Type:\\s*text/plain;\\s*charset=utf-8', 'i'),
    )
  }
  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/releases\/v0\.7\.6\/usegoodai-imagines-tool-\*\s+Content-Type:\s*application\/octet-stream\s+Cache-Control:\s*public,\s*max-age=31536000,\s*immutable/i,
  )
  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/releases\/v0\.7\.6\/SHA256SUMS\s+Content-Type:\s*text\/plain;\s*charset=utf-8\s+Cache-Control:\s*public,\s*max-age=31536000,\s*immutable/i,
  )
})

test('keeps the published V0.7.3 checksums immutable', async () => {
  const legacyRoot = new URL(
    'install/usegoodai-imagines-tool/releases/v0.7.3/',
    publicRoot,
  )
  const checksum = await readFile(
    new URL('SHA256SUMS', legacyRoot),
    'utf8',
  )
  const expected = {
    'usegoodai-imagines-tool-v0.7.3-windows-amd64.exe': 'fa4fe114ce64cba82e0005813d65c832537d94892f3437ad3d71d7e96597aa45',
    'usegoodai-imagines-tool-v0.7.3-darwin-arm64': '0a07c944e11048444d16679725c3f4747cfcfecc1bfa4018b6ff8a70c86a289c',
    'usegoodai-imagines-tool-v0.7.3-darwin-amd64': 'af72026e9b6c21075293f841c6e1c0b7993da48a8749fc1c04ce1196fad6db1e',
  }
  assert.deepEqual(Object.fromEntries(parseChecksums(checksum)), expected)
  for (const [name, digest] of Object.entries(expected)) {
    const artifact = await readFile(new URL(name, legacyRoot))
    assert.equal(createHash('sha256').update(artifact).digest('hex'), digest)
  }
})
