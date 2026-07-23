export const EXCHANGE_RATE = 7

export const TEXT_GROUPS = [
  {
    id: 'pro-plus',
    name: 'GPT Plus 特惠分组',
    multiplier: 0.1,
    description: '适合体验',
  },
  {
    id: 'gpt-0.16',
    name: 'Pro / Plus 混合分组',
    multiplier: 0.16,
    description: '适合日常',
  },
  {
    id: 'full',
    name: '正价满血分组',
    multiplier: 0.25,
    description: '完整能力，适合重要任务',
  },
]

export const TEXT_MODELS = [
  {
    id: 'gpt-5.6-sol',
    name: 'GPT-5.6 Sol',
    description: '复杂任务、深度推理和专业代码',
    officialUsd: { input: 5, output: 30, cachedInput: 0.5 },
  },
  {
    id: 'gpt-5.6-terra',
    name: 'GPT-5.6 Terra',
    description: '日常代码、通用任务和稳定对话',
    officialUsd: { input: 2.5, output: 15, cachedInput: 0.25 },
  },
  {
    id: 'gpt-5.6-luna',
    name: 'GPT-5.6 Luna',
    description: '轻量任务、批量处理和成本优先',
    officialUsd: { input: 1, output: 6, cachedInput: 0.1 },
  },
  {
    id: 'gpt-5.5',
    name: 'GPT-5.5',
    description: '重要任务、复杂代码和专业分析',
    officialUsd: { input: 5, output: 30, cachedInput: 0.5 },
  },
  {
    id: 'gpt-5.4',
    name: 'GPT-5.4',
    description: '普通工作、日常代码和稳定对话',
    officialUsd: { input: 2.5, output: 15, cachedInput: 0.25 },
  },
  {
    id: 'gpt-5.4-mini',
    name: 'GPT-5.4 mini',
    description: '简单操作、批量小任务和低成本场景',
    officialUsd: { input: 0.75, output: 4.5, cachedInput: 0.075 },
  },
]

export const IMAGE_GROUP = {
  id: 'image',
  name: '绘图分组',
  description: '图片生成统一按张计费',
  priceCny: 0.05,
}

export const IMAGE_MODELS = [
  {
    id: 'gpt-image-2',
    name: 'GPT Image 2',
    description: '图片生成与图片编辑',
    size: '1024 × 1024',
    quality: '标准画质',
    officialUsdPerImage: 0.053,
  },
]

export function calculateTextPrice(officialUsd, multiplier) {
  const official = {
    input: officialUsd.input * EXCHANGE_RATE,
    output: officialUsd.output * EXCHANGE_RATE,
    cachedInput: officialUsd.cachedInput * EXCHANGE_RATE,
    total: (officialUsd.input + officialUsd.output) * EXCHANGE_RATE,
  }

  const group = {
    input: officialUsd.input * multiplier,
    output: officialUsd.output * multiplier,
    cachedInput: officialUsd.cachedInput * multiplier,
    total: (officialUsd.input + officialUsd.output) * multiplier,
  }

  return { official, group }
}

export function getEquivalentDiscount(multiplier) {
  return `${((multiplier / EXCHANGE_RATE) * 10).toFixed(1)}折`
}

export function getImageDiscount(priceCny, officialUsdPerImage) {
  const officialCny = officialUsdPerImage * EXCHANGE_RATE
  return `${((priceCny / officialCny) * 10).toFixed(1)}折`
}

export function formatCny(value) {
  return `¥${value.toFixed(2)}`
}
