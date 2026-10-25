import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const imageToolDocSource = readFileSync(
  new URL('../docs/image-video-group-image.md', import.meta.url),
  'utf8',
)
const paramsSource = readFileSync(new URL('../docs/images/params.md', import.meta.url), 'utf8')
const apiDocSource = readFileSync(
  new URL('../docs/images/image-generation.md', import.meta.url),
  'utf8',
)

function sectionContent(heading) {
  const start = paramsSource.indexOf(`${heading}\n`)
  assert.notEqual(start, -1, `missing section: ${heading}`)
  const contentStart = start + heading.length
  const next = paramsSource.indexOf('\n## ', contentStart)
  return paramsSource.slice(contentStart, next === -1 ? undefined : next)
}

test('makes GPT Image 2.5 the complete primary GPT Image guide', () => {
  const gptImage25 = sectionContent('## GPT Image 2.5 {#gpt-image-2-5}')

  const resolutionMappings = [
    ['1K 方图', '1024x1024'],
    ['1K 横图', '1536x1024'],
    ['1K 竖图', '1024x1536'],
    ['2K 方图', '2048x2048'],
    ['2K 横图', '2048x1152'],
    ['2K 竖图', '1152x2048'],
    ['4K 横图', '3840x2160'],
    ['4K 竖图', '2160x3840'],
  ]
  const ratioMappings = [
    ['1:1', '1024x1024'],
    ['3:2', '1152x768'],
    ['2:3', '768x1152'],
    ['3:4', '768x1024'],
    ['4:3', '1024x768'],
    ['4:5', '768x960'],
    ['5:4', '960x768'],
    ['9:16', '720x1280'],
    ['16:9', '1280x720'],
    ['21:9', '1344x576'],
    ['9:21', '576x1344'],
    ['3:1', '1536x512'],
    ['1:3', '512x1536'],
  ]

  assert.match(gptImage25, /使用 `size`、`quality` 和 `output_format`/)
  assert.match(gptImage25, /宽高为 16 的倍数/)
  assert.match(gptImage25, /单边不超过 3840/)
  assert.match(gptImage25, /总像素为 655360 至 8294400/)
  assert.match(gptImage25, /`size=auto` 时模型根据提示词选择尺寸/)
  for (const [label, size] of resolutionMappings) {
    assert.ok(gptImage25.includes(`| ${label} | \`${size}\` |`), `missing resolution mapping: ${label}`)
  }
  for (const [ratio, size] of ratioMappings) {
    assert.ok(gptImage25.includes(`| ${ratio} | \`${size}\` |`), `missing ratio mapping: ${ratio}`)
  }
  assert.match(gptImage25, /`2880x2880`/)
  assert.match(gptImage25, /比例超过 3:1 的 `4:1`、`1:4`、`8:1`、`1:8` 不支持/)
  assert.match(gptImage25, /超过 `2560x1440` 的输出属于实验性范围/)
  assert.match(gptImage25, /`xhigh` 和 `max` 只适用于两个 GPT Image 2\.5 模型/)
})

test('points the API guide and the tool page to the params page', () => {
  assert.match(apiDocSource, /\[生图参数汇总\]\(\/images\/params\)/)
  assert.match(apiDocSource, /"model": "gpt-image-2\.5-flare"/)
  assert.match(imageToolDocSource, /\[生图参数汇总\]\(\/images\/params\)/)
})

test('keeps only the GPT Image 2 quality difference', () => {
  const gptImage2 = sectionContent('## GPT Image 2')
  assert.match(gptImage2, /`low`、`medium`、`high`、`auto`/)
  assert.match(gptImage2, /不支持 `xhigh` 和 `max`/)
  assert.doesNotMatch(gptImage2, /\/v1\/images|`size`|`n`|`aspect_ratio`|`resolution`/)
})

test('keeps the default model routing rule in the DIY prompt', () => {
  const routingRule = '模型选择顺序固定为：用户明确指定模型时使用该模型；未指定模型且明确要求高清、高质量、精细细节、精修、严格保留原图或重要成品时使用 gpt-image-2.5-sunburst；其余未指定模型的任务默认使用 gpt-image-2.5-flare。'
  assert.ok(imageToolDocSource.includes(routingRule))
  assert.match(imageToolDocSource, /`gpt-image-2\.5-flare` \| 默认模型/)
  assert.match(imageToolDocSource, /`gpt-image-2\.5-sunburst` \| 说“高清”“精修”“重要成品”时自动使用/)
})
