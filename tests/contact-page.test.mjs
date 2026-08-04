import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const contactSource = readFileSync(new URL('../docs/contact.md', import.meta.url), 'utf8')
const themeSource = readFileSync(new URL('../docs/.vitepress/theme/custom.css', import.meta.url), 'utf8')

test('shows the QQ group trial offer for new users', () => {
  assert.match(contactSource, /新用户进群后，直接私发账号邮箱给群主/)
  assert.match(contactSource, /领取 2 元人民币试用金，可使用 500 万 Token 的 GPT-5\.6 Sol/)
  assert.match(contactSource, /contact-offer/)
})

test('keeps the larger reading size and refreshed theme palette', () => {
  assert.match(themeSource, /\.vp-doc\s*\{[\s\S]*?font-size:\s*21px/)
  assert.match(themeSource, /--vp-c-brand-1:\s*#cf4f4b/)
})
