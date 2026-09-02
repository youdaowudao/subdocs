import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const imageToolDocSource = readFileSync(
  new URL('../docs/image-video-group-image.md', import.meta.url),
  'utf8',
)
const apiDocSource = readFileSync(
  new URL('../docs/images/image-generation.md', import.meta.url),
  'utf8',
)

test('documents GPT Image 2 pixel-size ratio mapping', () => {
  assert.match(imageToolDocSource, /`gpt-image-2`[\s\S]*?使用 `size`、`quality` 和 `output_format`/)
  assert.match(imageToolDocSource, /3:4[\s\S]{0,120}`768x1024`/)
  assert.match(imageToolDocSource, /4:3[\s\S]{0,120}`1024x768`/)
  assert.match(imageToolDocSource, /9:16[\s\S]{0,120}`720x1280`/)
  assert.match(imageToolDocSource, /16:9[\s\S]{0,120}`1280x720`/)
  assert.match(imageToolDocSource, /3:1/)
  assert.match(imageToolDocSource, /比例超过 3:1 的 `4:1`、`1:4`、`8:1`、`1:8` 不支持/)
})

test('documents GPT Image 2 size constraints in the API guide', () => {
  assert.match(imageToolDocSource, /<span id="gpt-image-2"><\/span>/)
  assert.match(
    apiDocSource,
    /前往\[中转站生图工具的 GPT Image 2 说明\]\(\/image-video-group-image#gpt-image-2\).*点击“GPT Image 2：尺寸、质量、比例和接口”展开查看/,
  )
  assert.match(apiDocSource, /宽高必须是 16 的倍数/)
  assert.match(apiDocSource, /长边与短边的比例不超过 3:1/)
  assert.match(apiDocSource, /总像素在 655360 到 8294400 之间/)
})
