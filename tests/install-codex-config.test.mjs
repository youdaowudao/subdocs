import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'

const installers = [
  ['Shell', new URL('../docs/public/install/codex.sh', import.meta.url)],
  ['PowerShell', new URL('../docs/public/install/codex.ps1', import.meta.url)],
]

for (const [name, path] of installers) {
  test(`${name} installer writes the required OpenAI auth config`, async () => {
    const installer = await readFile(path, 'utf8')

    assert.match(installer, /^requires_openai_auth = true$/m)
    assert.doesNotMatch(installer, /x-openai-actor-authorization|local-image-extension/)
  })
}
