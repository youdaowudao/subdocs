import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'

const installers = [
  [
    'Shell',
    new URL('../docs/public/install/codex.sh', import.meta.url),
    new URL('../usegoodai-codex-installer/install/codex.sh', import.meta.url),
  ],
  [
    'PowerShell',
    new URL('../docs/public/install/codex.ps1', import.meta.url),
    new URL('../usegoodai-codex-installer/install/codex.ps1', import.meta.url),
  ],
]

for (const [name, path, sourcePath] of installers) {
  test(`${name} installer writes the required OpenAI auth config`, async () => {
    const installer = await readFile(path, 'utf8')

    assert.match(installer, /^requires_openai_auth = true$/m)
    assert.doesNotMatch(installer, /x-openai-actor-authorization|local-image-extension/)
  })

  test(`published ${name} installer matches the installer source`, async () => {
    const installer = await readFile(path, 'utf8')
    const source = await readFile(sourcePath, 'utf8')

    assert.equal(installer, source)
  })
}

for (const name of ['codex-restore.sh', 'codex-restore.ps1']) {
  test(`published ${name} matches the installer source`, async () => {
    const installer = await readFile(new URL(`../docs/public/install/${name}`, import.meta.url), 'utf8')
    const source = await readFile(new URL(`../usegoodai-codex-installer/install/${name}`, import.meta.url), 'utf8')

    assert.equal(installer, source)
  })
}
