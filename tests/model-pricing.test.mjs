import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

import {
  EXCHANGE_RATE,
  IMAGE_GROUP,
  IMAGE_MODELS,
  MODEL_CATEGORIES,
  TEXT_GROUPS,
  calculateImagePriceCny,
  calculateTextPrice,
  formatCny,
  getTextModelsForGroup,
  getEquivalentDiscount,
  getSavingsPercent,
} from '../docs/.vitepress/theme/components/model-pricing-data.mjs'

const pricingComponentSource = readFileSync(
  new URL('../docs/.vitepress/theme/components/ModelPricing.vue', import.meta.url),
  'utf8',
)
const modelsDocSource = readFileSync(new URL('../docs/models.md', import.meta.url), 'utf8')
const vitepressConfigSource = readFileSync(new URL('../docs/.vitepress/config.mts', import.meta.url), 'utf8')
const imageGroupDocSource = readFileSync(new URL('../docs/images/image-video-group-image.md', import.meta.url), 'utf8')

const isClose = (actual, expected) => Math.abs(actual - expected) < 1e-12

test('includes the updated GPT pricing groups in order', () => {
  assert.deepEqual(
    TEXT_GROUPS.map(({ id, name, multiplier }) => ({ id, name, multiplier })),
    [
      { id: 'pro-plus', name: 'GPT Plus 特惠分组（最近不稳定）', multiplier: 0.095 },
      { id: 'gpt-0.18', name: 'GPT Pro / Plus 混池分组', multiplier: 0.15 },
      { id: 'full', name: 'GPT 正价 Pro 满血分组', multiplier: 0.25 },
      { id: 'anthropic-main', name: '主力分组', multiplier: 0.25 },
      { id: 'anthropic-max', name: 'CC MAX 满血版本', multiplier: 1.3 },
      { id: 'grok-4.5', name: 'Grok 4.5 分组', multiplier: 0.1 },
      { id: 'gemini-antigravity', name: 'Gemini 分组（反重力 Antigravity 反代）', multiplier: 0.25 },
      { id: 'domestic', name: '国产之光', multiplier: 0.2 },
    ],
  )
})

test('keeps the model category tabs in the requested order', () => {
  assert.deepEqual(
    MODEL_CATEGORIES.map(({ id, name, kind, groupIds, defaultGroupId }) => ({ id, name, kind, groupIds, defaultGroupId })),
    [
      { id: 'gpt', name: 'GPT', kind: 'text', groupIds: ['pro-plus', 'gpt-0.18', 'full'], defaultGroupId: 'gpt-0.18' },
      { id: 'anthropic', name: 'Anthropic', kind: 'text', groupIds: ['anthropic-main', 'anthropic-max'], defaultGroupId: undefined },
      { id: 'grok', name: 'Grok', kind: 'text', groupIds: ['grok-4.5'], defaultGroupId: undefined },
      { id: 'gemini', name: 'Gemini', kind: 'text', groupIds: ['gemini-antigravity'], defaultGroupId: undefined },
      { id: 'domestic', name: 'GLM', kind: 'text', groupIds: ['domestic'], defaultGroupId: undefined },
      { id: 'image', name: '生图', kind: 'image', groupIds: [], defaultGroupId: undefined },
    ],
  )
})

test('uses colored Claude Code, Grok and Gemini icons instead of letter placeholders', () => {
  const anthropic = MODEL_CATEGORIES.find((category) => category.id === 'anthropic')
  const grok = MODEL_CATEGORIES.find((category) => category.id === 'grok')
  const gemini = MODEL_CATEGORIES.find((category) => category.id === 'gemini')

  assert.equal(anthropic.mark, undefined)
  assert.match(anthropic.iconSvg, /fill="#D97757"/)
  assert.match(anthropic.iconSvg, /M4\.709 15\.955/)
  assert.match(grok.iconSvg, /fill="#141413"/)
  assert.equal(gemini.mark, undefined)
  assert.match(gemini.iconSvg, /fill="#8E75B2"/)
  assert.match(gemini.iconSvg, /M11\.04 19\.32/)
})

test('uses the requested Anthropic group recommendations', () => {
  const group = TEXT_GROUPS.find((item) => item.id === 'anthropic-main')
  const fable = getTextModelsForGroup('anthropic-main').find((model) => model.id === 'claude-fable-5')

  assert.equal(group.name, '主力分组')
  assert.equal(group.description, '写作推荐 Fable 5，复杂架构设计推荐 Opus 5')
  assert.equal(fable.description, 'Anthropic 写作向模型，适合长文创作、文案润色和自然表达')
})

test('keeps the GPT Plus discount group at 0.095 with instability copy', () => {
  const group = TEXT_GROUPS.find((item) => item.id === 'pro-plus')

  assert.equal(group.name, 'GPT Plus 特惠分组（最近不稳定）')
  assert.equal(group.multiplier, 0.095)
  assert.match(group.description, /最近不稳定/)
})

test('keeps the GPT family models in the expected order', () => {
  assert.deepEqual(
    getTextModelsForGroup('pro-plus').map((model) => model.id),
    [
      'gpt-5.6-sol',
      'gpt-5.6-terra',
      'gpt-5.6-luna',
      'gpt-5.5',
      'gpt-5.4',
      'gpt-5.4-mini',
    ],
  )
})

test('shows the main Anthropic group with the exact model list from the current whitelist', () => {
  assert.deepEqual(
    getTextModelsForGroup('anthropic-main').map((model) => model.id),
    [
      'claude-fable-5',
      'claude-haiku-4-5-20251001',
      'claude-opus-4-5-20251101',
      'claude-opus-4-6',
      'claude-opus-4-7',
      'claude-opus-4-8',
      'claude-opus-5',
      'claude-sonnet-4-6',
      'claude-sonnet-5',
    ],
  )
})

test('shows the CC MAX Claude group with the extra sonnet snapshot model', () => {
  assert.deepEqual(
    getTextModelsForGroup('anthropic-max').map((model) => model.id),
    [
      'claude-fable-5',
      'claude-haiku-4-5-20251001',
      'claude-opus-4-5-20251101',
      'claude-opus-4-6',
      'claude-opus-4-7',
      'claude-opus-4-8',
      'claude-opus-5',
      'claude-sonnet-4-5-20250929',
      'claude-sonnet-4-6',
      'claude-sonnet-5',
    ],
  )
})

test('shows Grok 4.5 as a standalone text group', () => {
  assert.deepEqual(
    getTextModelsForGroup('grok-4.5').map((model) => model.id),
    ['grok-4.5'],
  )
})

test('shows the Gemini Antigravity group with newest models first and Pro before Flash', () => {
  assert.deepEqual(
    getTextModelsForGroup('gemini-antigravity').map((model) => model.id),
    [
      'gemini-3.6-flash-tiered',
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-3.1-pro-preview',
      'gemini-3.1-flash-lite',
      'gemini-3.1-flash-lite-preview',
      'gemini-3-pro-preview',
      'gemini-3-flash',
      'gemini-3-flash-preview',
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
    ],
  )
})

test('shows GLM-5.2 and LongCat-2.0 together in the RMB domestic group', () => {
  const group = TEXT_GROUPS.find((item) => item.id === 'domestic')

  assert.equal(group.name, '国产之光')
  assert.equal(group.multiplier, 0.2)
  assert.equal(group.currency, 'cny')
  assert.match(group.description, /逆向/)
  assert.deepEqual(
    getTextModelsForGroup('domestic').map(({ id, officialCny }) => ({ id, officialCny })),
    [
      { id: 'glm-5.2', officialCny: { input: 8, output: 20, cachedInput: 2 } },
      { id: 'LongCat-2.0', officialCny: { input: 2, output: 8, cachedInput: 0.04 } },
    ],
  )
})

test('uses the displayed official price baselines for GPT-5.6', () => {
  assert.deepEqual(
    getTextModelsForGroup('gpt-0.18').slice(0, 3).map((model) => model.officialUsd),
    [
      { input: 5, output: 30, cachedInput: 0.5 },
      { input: 2.5, output: 15, cachedInput: 0.25 },
      { input: 1, output: 6, cachedInput: 0.1 },
    ],
  )
})

test('uses the displayed official price baselines for Gemini text models', () => {
  const models = new Map(getTextModelsForGroup('gemini-antigravity').map((model) => [model.id, model]))

  assert.deepEqual(models.get('gemini-3.6-flash').officialUsd, { input: 1.5, output: 7.5, cachedInput: 0.15 })
  assert.deepEqual(models.get('gemini-3.1-pro-preview').officialUsd, { input: 2, output: 12, cachedInput: 0.2 })
  assert.deepEqual(models.get('gemini-2.5-pro').officialUsd, { input: 1.25, output: 10, cachedInput: 0.125 })
})

test('keeps Gemini descriptions customer-facing with dates or concrete use cases', () => {
  const models = new Map(getTextModelsForGroup('gemini-antigravity').map((model) => [model.id, model]))
  const forbidden = /旧预览|预览 ID|上一代|后台|Moxing|没的写/

  for (const model of models.values()) {
    assert.doesNotMatch(model.description, forbidden, model.id)
  }

  assert.match(models.get('gemini-3.6-flash').description, /2026-07/)
  assert.match(models.get('gemini-3.5-flash').description, /2026-05/)
  assert.match(models.get('gemini-3.1-pro-preview').description, /2026-02/)
  assert.match(models.get('gemini-3-pro-preview').description, /2025-11/)
  assert.match(models.get('gemini-2.5-pro').description, /2025-06/)
  assert.match(models.get('gemini-2.5-flash-lite').description, /高频|低延迟/)
})

test('converts official USD prices to RMB at the fixed exchange rate', () => {
  const price = calculateTextPrice(
    { input: 5, output: 30, cachedInput: 0.5 },
    0.1,
  )

  assert.deepEqual(price.official, {
    input: 35,
    output: 210,
    cachedInput: 3.5,
    total: 245,
  })
})

test('uses the group multiplier directly on the official USD number', () => {
  const price = calculateTextPrice(
    { input: 5, output: 30, cachedInput: 0.5 },
    0.25,
  )

  assert.ok(isClose(price.group.input, 1.25))
  assert.ok(isClose(price.group.output, 7.5))
  assert.ok(isClose(price.group.cachedInput, 0.125))
  assert.ok(isClose(price.group.total, 8.75))
})

test('calculates domestic model prices directly in RMB without USD conversion', () => {
  const price = calculateTextPrice(
    { input: 8, output: 20, cachedInput: 2 },
    0.2,
    'cny',
  )

  assert.deepEqual(price.official, {
    input: 8,
    output: 20,
    cachedInput: 2,
    total: 28,
  })
  assert.ok(isClose(price.group.input, 1.6))
  assert.ok(isClose(price.group.output, 4))
  assert.ok(isClose(price.group.cachedInput, 0.4))
  assert.ok(isClose(price.group.total, 5.6))
})

test('expresses the active multipliers as rounded equivalent discounts', () => {
  assert.equal(getEquivalentDiscount(0.1), '0.1折')
  assert.equal(getEquivalentDiscount(0.15), '0.2折')
  assert.equal(getEquivalentDiscount(0.25), '0.4折')
  assert.equal(getEquivalentDiscount(0.3), '0.4折')
  assert.equal(getEquivalentDiscount(1.9), '2.7折')
  assert.equal(getEquivalentDiscount(0.2, 'cny'), '2.0折')
  assert.equal(getSavingsPercent(0.2, 'cny'), 80)
})

test('calculates the revised group totals from the official USD baseline', () => {
  const officialUsd = { input: 5, output: 30, cachedInput: 0.5 }
  const expectedTotals = new Map([
    ['pro-plus', 3.325],
    ['gpt-0.18', 5.25],
    ['full', 8.75],
    ['anthropic-main', 8.75],
    ['anthropic-max', 45.5],
    ['grok-4.5', 3.5],
    ['gemini-antigravity', 8.75],
  ])

  for (const [groupId, expectedTotal] of expectedTotals) {
    const group = TEXT_GROUPS.find((item) => item.id === groupId)
    const price = calculateTextPrice(officialUsd, group.multiplier)

    assert.ok(isClose(price.group.total, expectedTotal), groupId)
  }
})

test('keeps the model pricing page out of the global navigation chrome', () => {
  assert.match(modelsDocSource, /^navbar:\s*false$/m)
  assert.match(modelsDocSource, /^sidebar:\s*false$/m)
  assert.doesNotMatch(vitepressConfigSource, /text:\s*'模型价格',\s*link:\s*'\/models'/)
  assert.match(vitepressConfigSource, /excludeByGlobPattern:\s*\[[^\]]*'models\.md'/s)
})

test('reserves the pricing-group area while official prices are selected', () => {
  assert.match(pricingComponentSource, /v-else\s+class="pricing-groups pricing-groups--placeholder"/)
  assert.match(pricingComponentSource, /v-for="group in activeGroups"/)
  assert.match(pricingComponentSource, /class="pricing-group-card pricing-group-placeholder"/)
})

test('formats RMB amounts without noisy trailing zeroes', () => {
  assert.equal(formatCny(245), '¥245.00')
  assert.equal(formatCny(0.525), '¥0.53')
  assert.equal(formatCny(1.25), '¥1.25')
})

test('formats tiny non-zero RMB amounts without rounding them to zero', () => {
  assert.equal(formatCny(0.0049), '¥0.0049')
})

test('marks the image group as RMB pricing without multiplying the original per-image prices', () => {
  assert.equal(EXCHANGE_RATE, 7)
  assert.match(IMAGE_GROUP.description, /人民币/)
  assert.equal(calculateImagePriceCny(0.03), 0.03)
  assert.equal(calculateImagePriceCny(0.05), 0.05)
  assert.equal(calculateImagePriceCny(0.2), 0.2)
  assert.deepEqual(
    IMAGE_MODELS.slice(0, 3).map((model) => ({
      id: model.id,
      cny: calculateImagePriceCny(model.groupCnyPerImage),
    })),
    [
      { id: 'gpt-image-1k-th', cny: 0.03 },
      { id: 'gpt-image-2', cny: 0.05 },
      { id: 'gpt-image-2-4k', cny: 0.08 },
    ],
  )
})

test('publishes Grok Imagine Image at 0.12 RMB per image', () => {
  const grok = IMAGE_MODELS.find((model) => model.id === 'grok-imagine-image')

  assert.ok(grok, 'grok-imagine-image should be published')
  assert.deepEqual(
    {
      id: grok.id,
      name: grok.name,
      route: grok.route,
      spec: grok.spec,
      groupCnyPerImage: grok.groupCnyPerImage,
    },
    {
      id: 'grok-imagine-image',
      name: 'Grok Imagine Image',
      route: '/v1/images/generations',
      spec: '自动尺寸',
      groupCnyPerImage: 0.12,
    },
  )
})

test('keeps the Grok request inside the existing Codex rules', () => {
  const codexRulesMatch = imageGroupDocSource.match(
    /::: details Codex 必须遵守的调用规则\n([\s\S]*?)\n:::/,
  )

  assert.ok(codexRulesMatch, 'the Codex rules details block should be present')

  const codexRules = codexRulesMatch[1]
  const grokSectionMatch = codexRules.match(
    /### Grok Imagine 请求\n([\s\S]*?)\n+当前已经确认并可直接使用的 Images 编辑模板/,
  )
  const agentsRulesMatch = codexRules.match(/```md\n## 项目生图规则\n([\s\S]*?)\n```/)

  assert.doesNotMatch(imageGroupDocSource, /^## 用 Python 接入 Grok Imagine$/m)
  assert.ok(grokSectionMatch, 'the Grok request should be in the existing Codex rules')
  assert.equal((codexRules.match(/### Grok Imagine 请求/g) || []).length, 1)
  assert.ok(agentsRulesMatch, 'the project image rules should be present')

  const jsonBlock = grokSectionMatch[1].match(/```json\n([\s\S]*?)\n```/)
  assert.ok(jsonBlock, 'the Grok request body should be present')
  assert.deepEqual(JSON.parse(jsonBlock[1]), {
    model: 'grok-imagine-image',
    prompt: '<运行脚本时收到的图片描述>',
    n: 1,
    response_format: 'b64_json',
  })
  assert.match(grokSectionMatch[1], /1 到 9/)
  assert.match(grokSectionMatch[1], /data\[\]\.b64_json/)
  assert.match(grokSectionMatch[1], /data\[\]\.url/)
  assert.match(grokSectionMatch[1], /JPEG 或 PNG/)

  const agentsRules = agentsRulesMatch[1]
  assert.match(agentsRules, /可用模型只有：[\s\S]*?`grok-imagine-image`/)
  assert.match(agentsRules, /`grok-imagine-image` 使用 `\/v1\/images\/generations`/)
  assert.match(agentsRules, /`response_format: "b64_json"`/)
  assert.match(agentsRules, /`n` 只能是 1 到 9/)
  assert.match(agentsRules, /不得发送 `size`、`quality`、`style`、`aspect_ratio` 或 `resolution`/)
})

test('keeps image model descriptions customer-facing without backend mapping wording', () => {
  const forbidden = /Google|Gemini|Firefly|Partner Model|账号渠道|YS 渠道|xAI|后台|映射/

  for (const model of IMAGE_MODELS) {
    assert.doesNotMatch(model.description, forbidden, model.id)
    assert.doesNotMatch(model.spec, /渠道档/, model.id)
  }
})
