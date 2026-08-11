import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const imageGroupDocSource = readFileSync(
  new URL('../docs/images/image-video-group-image.md', import.meta.url),
  'utf8',
)

test('keeps both Nano Banana models and Responses request inside the Codex rules', () => {
  const codexRulesMatch = imageGroupDocSource.match(
    /::: details Codex 必须遵守的调用规则\n([\s\S]*?)\n:::/,
  )

  assert.ok(codexRulesMatch, 'the Codex rules details block should be present')

  const codexRules = codexRulesMatch[1]
  const bananaSectionMatch = codexRules.match(
    /### Nano Banana 请求\n([\s\S]*?)\n+`gpt-image-2`、`gpt-image-1k-th` 和 `grok-imagine-image` 可以使用 Images 编辑接口/,
  )

  assert.ok(bananaSectionMatch, 'the Nano Banana request should be in the existing Codex rules')
  assert.equal((codexRules.match(/### Nano Banana 请求/g) || []).length, 1)
  assert.match(codexRules, /`nano-banana-2`/)
  assert.match(codexRules, /`nano-banana-pro`/)
  assert.match(codexRules, /POST https:\/\/api\.usegoodai\.com\/v1\/responses/)
  assert.match(bananaSectionMatch[1], /`512`、`1K`、`2K`、`4K`/)
  assert.match(bananaSectionMatch[1], /最多传入 14 张 PNG、JPEG 或 WebP/)
  assert.match(bananaSectionMatch[1], /Markdown Data URL/)

  const jsonBlock = bananaSectionMatch[1].match(/```json\n([\s\S]*?)\n```/)
  assert.ok(jsonBlock, 'the Nano Banana request body should be present')
  assert.deepEqual(JSON.parse(jsonBlock[1]), {
    model: 'nano-banana-2',
    input: [
      {
        role: 'user',
        content: [
          {
            type: 'input_text',
            text: '<运行脚本时收到的图片描述>',
          },
        ],
      },
    ],
    stream: false,
    response_format: {
      type: 'image',
      mime_type: 'image/png',
      aspect_ratio: '16:9',
      image_size: '2K',
    },
  })
})
