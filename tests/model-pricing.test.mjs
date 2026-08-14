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

const isClose = (actual, expected) => Math.abs(actual - expected) < 1e-12

test('includes the updated GPT pricing groups in order', () => {
  assert.deepEqual(
    TEXT_GROUPS.map(({ id, name, multiplier }) => ({ id, name, multiplier })),
    [
      { id: 'pro-plus', name: 'GPT Plus 特惠分组（最近不稳定）', multiplier: 0.095 },
      { id: 'gpt-0.18', name: 'GPT Pro / Plus 混池分组', multiplier: 0.15 },
      { id: 'full', name: 'GPT 正价 Pro 满血分组', multiplier: 0.25 },
      { id: 'anthropic-main', name: '主力分组', multiplier: 0.3 },
      { id: 'anthropic-max', name: 'CC MAX 满血版本', multiplier: 1.3 },
      { id: 'grok-4.5', name: 'heavy号池', multiplier: 0.35 },
      { id: 'gemini-antigravity', name: 'Gemini 分组（反重力 Antigravity 反代）', multiplier: 0.25 },
      { id: 'deepseek-v4-flash', name: 'DeepSeek V4 Flash 分组', multiplier: 0.4 },
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
      { id: 'deepseek', name: 'DeepSeek', kind: 'text', groupIds: ['deepseek-v4-flash'], defaultGroupId: undefined },
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

test('shows Grok 4.6 before Grok 4.5 with official prices and customer-facing descriptions', () => {
  assert.deepEqual(
    getTextModelsForGroup('grok-4.5').map(({ id, description, officialUsd }) => ({ id, description, officialUsd })),
    [
      {
        id: 'grok-4.6',
        description: 'XAI最新模型，性能直逼OPUS 5跟GPT 5.6 SOL，限制低，速度快，当前非常火热。',
        officialUsd: { input: 2, output: 6, cachedInput: 0.5 },
      },
      {
        id: 'grok-4.5',
        description: '速度比 GPT 日常分组更快，风控相对低，支持实时搜索和工具调用',
        officialUsd: { input: 2, output: 6, cachedInput: 0.2 },
      },
    ],
  )
})

test('shows the Gemini Antigravity group with newest models first and Pro before Flash', () => {
  assert.deepEqual(
    getTextModelsForGroup('gemini-antigravity').map((model) => model.id),
    [
      'gemini-3.7-flash',
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

test('shows DeepSeek V4 Flash 0731 with the official RMB prices and 0.4 multiplier', () => {
  const group = TEXT_GROUPS.find((item) => item.id === 'deepseek-v4-flash')
  const models = getTextModelsForGroup(group.id)

  assert.equal(group.multiplier, 0.4)
  assert.equal(group.currency, 'cny')
  assert.deepEqual(
    models.map(({ id, name, officialCny }) => ({ id, name, officialCny })),
    [
      {
        id: 'deepseek-v4-flash',
        name: 'DeepSeek V4 Flash 0731',
        officialCny: { input: 1, output: 2, cachedInput: 0.02 },
      },
    ],
  )

  const price = calculateTextPrice(models[0].officialCny, group.multiplier, group.currency)
  assert.deepEqual(price.official, { input: 1, output: 2, cachedInput: 0.02, total: 3 })
  assert.ok(isClose(price.group.input, 0.4))
  assert.ok(isClose(price.group.output, 0.8))
  assert.ok(isClose(price.group.cachedInput, 0.008))
  assert.ok(isClose(price.group.total, 1.2))
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

  assert.deepEqual(models.get('gemini-3.7-flash').officialUsd, { input: 0.75, output: 3.75, cachedInput: 0.075 })
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

  assert.match(models.get('gemini-3.7-flash').description, /2026-08/)
  assert.match(models.get('gemini-3.7-flash').description, /2026-12-31/)
  assert.match(models.get('gemini-3.6-flash').description, /2026-07/)
  assert.match(models.get('gemini-3.5-flash').description, /2026-05/)
  assert.match(models.get('gemini-3.1-pro-preview').description, /2026-02/)
  assert.match(models.get('gemini-3-pro-preview').description, /2025-11/)
  assert.match(models.get('gemini-2.5-pro').description, /2025-06/)
  assert.match(models.get('gemini-2.5-flash-lite').description, /高频|低延迟/)
})

test('highlights Gemini 3.7 Flash as the featured model', () => {
  const model = getTextModelsForGroup('gemini-antigravity')[0]

  assert.equal(model.id, 'gemini-3.7-flash')
  assert.equal(model.featured, true)
  assert.equal(model.featuredLabel, '主推')
  assert.match(pricingComponentSource, /'is-featured-model': model\.featured/)
  assert.match(pricingComponentSource, /class="featured-model-badge"/)
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
    ['anthropic-main', 10.5],
    ['anthropic-max', 45.5],
    ['grok-4.5', 12.25],
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

test('keeps the requested drawing prices in RMB without applying USD conversion', () => {
  assert.equal(EXCHANGE_RATE, 7)
  assert.match(IMAGE_GROUP.description, /人民币/)
  assert.equal(calculateImagePriceCny(0.03), 0.03)
  assert.equal(calculateImagePriceCny(0.05), 0.05)
  assert.equal(calculateImagePriceCny(0.2), 0.2)
  const requestedPrices = new Map(
    IMAGE_MODELS.map((model) => [model.id, calculateImagePriceCny(model.groupCnyPerImage)]),
  )

  assert.deepEqual(
    [...requestedPrices].filter(([id]) => ['gpt-image-1k-th', 'gpt-image-2', 'gpt-image-2-adobe'].includes(id)),
    [
      ['gpt-image-1k-th', 0.03],
      ['gpt-image-2', 0.05],
      ['gpt-image-2-adobe', 0.12],
    ],
  )

  const gptImage2 = IMAGE_MODELS.find((model) => model.id === 'gpt-image-2')
  assert.deepEqual(gptImage2.sizePricesCny, [
    { size: '1K', cnyPerImage: 0.04 },
    { size: '2K', cnyPerImage: 0.05 },
    { size: '4K', cnyPerImage: 0.08 },
  ])
  assert.equal(gptImage2.spec, '1K / 2K / 4K')
  assert.match(pricingComponentSource, /v-if="model\.sizePricesCny"/)
  assert.match(pricingComponentSource, /按分辨率计费/)
})

test('shows the unified size-price note only for gpt-image-2-adobe', () => {
  const adobe = IMAGE_MODELS.find((model) => model.id === 'gpt-image-2-adobe')

  assert.equal(adobe.priceNote, '1/2/4k统一价')
  assert.match(pricingComponentSource, /model\.priceNote \?\? '当前分组默认价'/)
})

test('removes nonexistent GPT Image size aliases and the YS model from the pricing page', () => {
  const modelIds = new Set(IMAGE_MODELS.map((model) => model.id))

  for (const removedId of [
    'gpt-image-2-4k',
    'gpt-image-1k-adobe',
    'gpt-image-2k-adobe',
    'gpt-image-4k-adobe',
    'gpt-image-4k-ys',
  ]) {
    assert.equal(modelIds.has(removedId), false, removedId)
  }
})

test('publishes only the two requested Nano Banana models and RMB prices', () => {
  assert.deepEqual(
    IMAGE_MODELS
      .filter((model) => model.id.startsWith('nano-banana'))
      .map(({ id, groupCnyPerImage }) => ({ id, groupCnyPerImage })),
    [
      { id: 'nano-banana-pro', groupCnyPerImage: 0.25 },
      { id: 'nano-banana-2', groupCnyPerImage: 0.12 },
    ],
  )
})

test('publishes Grok Imagine Image at 0.10 RMB per image', () => {
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
      groupCnyPerImage: 0.10,
    },
  )
})

test('keeps image model descriptions customer-facing without backend mapping wording', () => {
  const forbidden = /Google|Gemini|Firefly|Partner Model|账号渠道|YS 渠道|xAI|后台|映射/

  for (const model of IMAGE_MODELS) {
    assert.doesNotMatch(model.description, forbidden, model.id)
    assert.doesNotMatch(model.spec, /渠道档/, model.id)
  }
})
