import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { readFile, readdir } from 'node:fs/promises'
import test from 'node:test'

// The site keeps the current release and the previous stable one, so users
// can go back when the new version fails on their machine.
const currentVersion = '0.9.2'
const previousVersion = '0.9.1'

const publicRoot = new URL('../docs/public/', import.meta.url)
const entryRoot = new URL('install/usegoodai-imagines-tool/', publicRoot)
const releasesRoot = new URL('install/usegoodai-imagines-tool/releases/', publicRoot)
const previousRoot = new URL('previous/', entryRoot)
const headersUrl = new URL('_headers', publicRoot)

function releaseRoot(version) {
  return new URL(`v${version}/`, releasesRoot)
}

function artifactNames(version) {
  return ['windows-amd64.exe', 'darwin-arm64', 'darwin-amd64', 'linux-amd64']
    .map((platform) => `usegoodai-imagines-tool-v${version}-${platform}`)
}

function escaped(version) {
  return version.replaceAll('.', '\\.')
}

function parseChecksums(text) {
  return new Map(
    text.trim().split('\n').map((line) => {
      const match = line.match(/^([0-9a-f]{64})\s{2}(.+)$/)
      assert.ok(match, `invalid checksum line: ${line}`)
      return [match[2], match[1]]
    }),
  )
}

async function checkRelease(version, scriptsRoot) {
  const root = releaseRoot(version)
  const names = artifactNames(version)
  assert.deepEqual((await readdir(root)).sort(), ['SHA256SUMS', ...names].sort())
  const [shell, powershell, checksum, ...artifacts] = await Promise.all([
    readFile(new URL('install.sh', scriptsRoot), 'utf8'),
    readFile(new URL('install.ps1', scriptsRoot), 'utf8'),
    readFile(new URL('SHA256SUMS', root), 'utf8'),
    ...names.map((name) => readFile(new URL(name, root))),
  ])
  const checksums = parseChecksums(checksum)
  assert.equal(checksums.size, names.length)

  for (const [index, name] of names.entries()) {
    const digest = createHash('sha256').update(artifacts[index]).digest('hex')
    assert.equal(checksums.get(name), digest)
    const installScript = name.includes('windows') ? powershell : shell
    assert.match(installScript, new RegExp(digest))
  }
  for (const script of [shell, powershell]) {
    assert.match(script, new RegExp(`releases/v${escaped(version)}"`))
    assert.doesNotMatch(script, /python|Expand-Archive|v0\.2-r1\.zip/i)
  }
  return { shell, powershell }
}

test('publishes exactly the current and the previous stable release', async () => {
  assert.deepEqual((await readdir(entryRoot)).sort(), ['install.ps1', 'install.sh', 'latest.json', 'previous', 'releases'])
  assert.deepEqual((await readdir(previousRoot)).sort(), ['install.ps1', 'install.sh'])
  assert.deepEqual(
    (await readdir(releasesRoot)).sort(),
    [`v${previousVersion}`, `v${currentVersion}`].sort(),
  )
  await checkRelease(previousVersion, previousRoot)
})

test('publishes the current native artifacts, scripts and checksums', async () => {
  const { shell, powershell } = await checkRelease(currentVersion, entryRoot)
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
  assert.match(combined, /linux-amd64/)
  assert.match(shell, /Darwin\/x86_64/)
  assert.match(shell, /sysctl\.proc_translated/)
  assert.match(shell, /expected_binary_format/)
  assert.doesNotMatch(combined, /windows-arm64|linux-arm64/)
})

test('publishes explicit content types and cache policy', async () => {
  const headers = await readFile(headersUrl, 'utf8')

  for (const scripts of ['', 'previous/']) {
    for (const name of ['install.ps1', 'install.sh']) {
      assert.match(
        headers,
        new RegExp(`/install/usegoodai-imagines-tool/${scripts}${name.replace('.', '\\.')}` +
          '\\s+Content-Type:\\s*text/plain;\\s*charset=utf-8\\s+Cache-Control:\\s*public,\\s*max-age=0,\\s*must-revalidate', 'i'),
      )
    }
  }
  for (const version of [currentVersion, previousVersion]) {
    const release = `/install/usegoodai-imagines-tool/releases/v${escaped(version)}/`
    assert.match(
      headers,
      new RegExp(`${release}usegoodai-imagines-tool-\\*\\s+Content-Type:\\s*application/octet-stream\\s+Cache-Control:\\s*public,\\s*max-age=31536000,\\s*immutable`, 'i'),
    )
    assert.match(
      headers,
      new RegExp(`${release}SHA256SUMS\\s+Content-Type:\\s*text/plain;\\s*charset=utf-8\\s+Cache-Control:\\s*public,\\s*max-age=31536000,\\s*immutable`, 'i'),
    )
  }
})

// The installed tool's update command reads latest.json (V0.9.2 on), so it
// must name the current release and never be served from a cache.
test('latest.json points the update command at the current release', async () => {
  const manifest = JSON.parse(await readFile(new URL('latest.json', entryRoot), 'utf8'))
  assert.equal(manifest.version, currentVersion)
  assert.equal(manifest.release, `V${currentVersion}`)
  const root = releaseRoot(currentVersion)
  const checksums = parseChecksums(await readFile(new URL('SHA256SUMS', root), 'utf8'))
  const platforms = {
    'windows/amd64': 'windows-amd64.exe',
    'darwin/arm64': 'darwin-arm64',
    'darwin/amd64': 'darwin-amd64',
    'linux/amd64': 'linux-amd64',
  }
  assert.deepEqual(Object.keys(manifest.files).sort(), Object.keys(platforms).sort())
  for (const [key, platform] of Object.entries(platforms)) {
    const name = `usegoodai-imagines-tool-v${currentVersion}-${platform}`
    const file = manifest.files[key]
    assert.equal(file.path, `releases/v${currentVersion}/${name}`)
    assert.equal(file.sha256, checksums.get(name))
    assert.equal(file.size, (await readFile(new URL(name, root))).length)
  }
  const headers = await readFile(headersUrl, 'utf8')
  assert.match(
    headers,
    /\/install\/usegoodai-imagines-tool\/latest\.json\s+Content-Type:\s*application\/json;\s*charset=utf-8\s+Cache-Control:\s*no-store/i,
  )
})
