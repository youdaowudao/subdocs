import test from 'node:test'
import assert from 'node:assert/strict'

import {
  TEXT_MODELS,
  calculateTextPrice,
  formatCny,
  getEquivalentDiscount,
} from '../docs/.vitepress/theme/components/model-pricing-data.mjs'

test('places the three GPT-5.6 models before the existing models', () => {
  assert.deepEqual(
    TEXT_MODELS.map((model) => model.id),
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

test('uses the displayed official price baselines for GPT-5.6', () => {
  assert.deepEqual(
    TEXT_MODELS.slice(0, 3).map((model) => model.officialUsd),
    [
      { input: 5, output: 30, cachedInput: 0.5 },
      { input: 2.5, output: 15, cachedInput: 0.25 },
      { input: 1, output: 6, cachedInput: 0.1 },
    ],
  )
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

  assert.deepEqual(price.group, {
    input: 1.25,
    output: 7.5,
    cachedInput: 0.125,
    total: 8.75,
  })
})

test('expresses 0.1 and 0.25 multipliers as rounded equivalent discounts', () => {
  assert.equal(getEquivalentDiscount(0.1), '0.1折')
  assert.equal(getEquivalentDiscount(0.25), '0.4折')
})

test('formats RMB amounts without noisy trailing zeroes', () => {
  assert.equal(formatCny(245), '¥245.00')
  assert.equal(formatCny(0.525), '¥0.53')
  assert.equal(formatCny(1.25), '¥1.25')
})
