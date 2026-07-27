import test from 'node:test'
import assert from 'node:assert/strict'

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
} from '../docs/.vitepress/theme/components/model-pricing-data.mjs'

const isClose = (actual, expected) => Math.abs(actual - expected) < 1e-12

test('includes the updated GPT pricing groups in order', () => {
  assert.deepEqual(
    TEXT_GROUPS.map(({ id, name, multiplier }) => ({ id, name, multiplier })),
    [
      { id: 'pro-plus', name: 'GPT Plus 特惠分组（最近不稳定）', multiplier: 0.12 },
      { id: 'gpt-0.18', name: 'GPT 日常分组', multiplier: 0.18 },
      { id: 'full', name: 'GPT 正价 Pro 满血分组', multiplier: 0.28 },
      { id: 'anthropic-main', name: '主力分组', multiplier: 0.4 },
      { id: 'anthropic-max', name: 'CC MAX 满血版本', multiplier: 1.9 },
      { id: 'grok-4.5', name: 'Grok 4.5 分组', multiplier: 0.15 },
      { id: 'gemini-antigravity', name: 'Gemini 分组（反重力 Antigravity 反代）', multiplier: 0.55 },
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

  assert.equal(group.name, '主力分组')
  assert.equal(group.description, '写作推荐 Opus 4.5，复杂架构设计推荐 Opus 4.8')
})

test('relaunches the GPT Plus discount group at 0.12 with instability copy', () => {
  const group = TEXT_GROUPS.find((item) => item.id === 'pro-plus')

  assert.equal(group.name, 'GPT Plus 特惠分组（最近不稳定）')
  assert.equal(group.multiplier, 0.12)
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
    0.28,
  )

  assert.ok(isClose(price.group.input, 1.4))
  assert.ok(isClose(price.group.output, 8.4))
  assert.ok(isClose(price.group.cachedInput, 0.14))
  assert.ok(isClose(price.group.total, 9.8))
})

test('expresses the active multipliers as rounded equivalent discounts', () => {
  assert.equal(getEquivalentDiscount(0.15), '0.2折')
  assert.equal(getEquivalentDiscount(0.12), '0.2折')
  assert.equal(getEquivalentDiscount(0.18), '0.3折')
  assert.equal(getEquivalentDiscount(0.28), '0.4折')
  assert.equal(getEquivalentDiscount(0.4), '0.6折')
  assert.equal(getEquivalentDiscount(0.55), '0.8折')
  assert.equal(getEquivalentDiscount(1.9), '2.7折')
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

test('keeps image model descriptions customer-facing without backend mapping wording', () => {
  const forbidden = /Google|Gemini|Firefly|Partner Model|账号渠道|YS 渠道|xAI|后台|映射/

  for (const model of IMAGE_MODELS) {
    assert.doesNotMatch(model.description, forbidden, model.id)
    assert.doesNotMatch(model.spec, /渠道档/, model.id)
  }
})
