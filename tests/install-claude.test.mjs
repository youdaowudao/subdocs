import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'

test('published Windows Claude command is the exact installer source', async () => {
  const source = await readFile(new URL('../usegoodai-codex-installer/install/claude.ps1', import.meta.url))
  const published = await readFile(new URL('../docs/public/install/claude.ps1', import.meta.url))
  assert.deepEqual(published, source)
  assert.notEqual(source.subarray(0, 3).toString('hex'), 'efbbbf')
})

test('Claude command has a fresh UTF-8 response and one documented entry', async () => {
  const headers = await readFile(new URL('../docs/public/_headers', import.meta.url), 'utf8')
  assert.match(headers, /\/install\/claude\.ps1\s+Content-Type: text\/plain; charset=utf-8\s+Cache-Control: public, max-age=0, must-revalidate/)
  const desktop = await readFile(new URL('../docs/claude/desktop.md', import.meta.url), 'utf8')
  assert.match(desktop, /irm https:\/\/docs\.usegoodai\.com\/install\/claude\.ps1 \| iex/)
})
