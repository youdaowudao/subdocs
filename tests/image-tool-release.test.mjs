import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import test from 'node:test'

const publicRoot = new URL('../docs/public/', import.meta.url)
const releaseRoot = new URL(
  'install/usegoodai-imagines-tool/releases/v0.2-r1/',
  publicRoot,
)
const archiveName = 'usegoodai-imagines-tool-v0.2-r1.zip'
const archiveUrl = new URL(archiveName, releaseRoot)
const shellUrl = new URL('install/usegoodai-imagines-tool/install.sh', publicRoot)
const powershellUrl = new URL('install/usegoodai-imagines-tool/install.ps1', publicRoot)
const shellUninstallUrl = new URL('install/usegoodai-imagines-tool/uninstall.sh', publicRoot)
const powershellUninstallUrl = new URL('install/usegoodai-imagines-tool/uninstall.ps1', publicRoot)
const checksumUrl = new URL('SHA256SUMS', releaseRoot)
const headersUrl = new URL('_headers', publicRoot)

function extract(pattern, text, label) {
  const match = text.match(pattern)
  assert.ok(match, `missing ${label}`)
  return match[1]
}

test('publishes matching V0.2-r1 scripts, archive and checksum', async () => {
  const [archive, shell, powershell, shellUninstall, powershellUninstall, checksum] = await Promise.all([
    readFile(archiveUrl),
    readFile(shellUrl, 'utf8'),
    readFile(powershellUrl, 'utf8'),
    readFile(shellUninstallUrl, 'utf8'),
    readFile(powershellUninstallUrl, 'utf8'),
    readFile(checksumUrl, 'utf8'),
  ])
  const digest = createHash('sha256').update(archive).digest('hex')
  const shellDigest = extract(/^package_sha256="([0-9a-f]{64})"$/m, shell, 'shell hash')
  const powershellDigest = extract(
    /^\$ExpectedSha256 = "([0-9a-f]{64})"$/m,
    powershell,
    'PowerShell hash',
  )
  const checksumDigest = extract(/^([0-9a-f]{64})\s{2}/m, checksum, 'checksum hash')

  assert.equal(shellDigest, digest)
  assert.equal(powershellDigest, digest)
  assert.match(shellUninstall, new RegExp(digest))
  assert.match(powershellUninstall, new RegExp(digest))
  assert.equal(checksumDigest, digest)
  assert.match(checksum, new RegExp(`${archiveName.replaceAll('.', '\\.')}\\s*$`))
})

test('publishes explicit content types and cache policy', async () => {
  const headers = await readFile(headersUrl, 'utf8')

  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/install\.ps1\s+Content-Type:\s*text\/plain;\s*charset=utf-8/i,
  )
  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/install\.sh\s+Content-Type:\s*text\/plain;\s*charset=utf-8/i,
  )
  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/uninstall\.ps1\s+Content-Type:\s*text\/plain;\s*charset=utf-8/i,
  )
  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/uninstall\.sh\s+Content-Type:\s*text\/plain;\s*charset=utf-8/i,
  )
  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/releases\/v0\.2-r1\/usegoodai-imagines-tool-v0\.2-r1\.zip\s+Content-Type:\s*application\/zip\s+Cache-Control:\s*public,\s*max-age=31536000,\s*immutable/i,
  )
})
