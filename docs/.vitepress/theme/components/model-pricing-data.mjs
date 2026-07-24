export const EXCHANGE_RATE = 7

export const TEXT_GROUPS = [
  {
    id: 'gpt-0.16',
    name: 'Pro / Plus 混合分组',
    multiplier: 0.16,
    description: '适合日常',
  },
  {
    id: 'full',
    name: '正价满血分组',
    multiplier: 0.28,
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
  name: '生图分组',
  description: '图片模型按当前分组默认价计费，单位为美元 / 张',
}

export const IMAGE_MODELS = [
  {
    id: 'gpt-image-1k-th',
    name: 'GPT Image 1K',
    description: 'GPT Image 2 的 1K 渠道档，适合低成本测试',
    route: '/v1/images/generations',
    spec: '1K',
    groupUsdPerImage: 0.03,
  },
  {
    id: 'gpt-image-2',
    name: 'GPT Image 2',
    description: 'OpenAI 通用生图与改图模型',
    route: '/v1/images/generations',
    spec: '按尺寸 / 画质',
    groupUsdPerImage: 0.05,
  },
  {
    id: 'gpt-image-2-4k',
    name: 'GPT Image 2 4K',
    description: 'GPT Image 2 的高分辨率渠道档',
    route: '/v1/images/generations',
    spec: '4K 渠道档',
    groupUsdPerImage: 0.08,
  },
  {
    id: 'gpt-image-1k-adobe',
    name: 'GPT Image 1K Adobe',
    description: 'Adobe Firefly Partner Model 账号渠道的 1K 档',
    route: '/v1/images/generations',
    spec: '1K 渠道档',
    groupUsdPerImage: 0.08,
  },
  {
    id: 'gpt-image-2k-adobe',
    name: 'GPT Image 2K Adobe',
    description: 'Adobe Firefly Partner Model 账号渠道的 2K 档',
    route: '/v1/images/generations',
    spec: '2K 渠道档',
    groupUsdPerImage: 0.15,
  },
  {
    id: 'gpt-image-4k-adobe',
    name: 'GPT Image 4K Adobe',
    description: 'Adobe Firefly Partner Model 账号渠道的 4K 档',
    route: '/v1/images/generations',
    spec: '4K 渠道档',
    groupUsdPerImage: 0.20,
  },
  {
    id: 'gpt-image-2-adobe',
    name: 'GPT Image 2 Adobe',
    description: 'Adobe Firefly Partner Model 账号渠道的 GPT Image 2',
    route: '/v1/images/generations',
    spec: '按尺寸 / 画质',
    groupUsdPerImage: 0.12,
  },
  {
    id: 'gpt-image-4k-ys',
    name: 'GPT Image 4K YS',
    description: 'YS 渠道的 GPT Image 高分辨率档',
    route: '/v1/images/generations',
    spec: '4K 渠道档',
    groupUsdPerImage: 0.20,
  },
  {
    id: 'nano-banana-pro',
    name: 'Nano Banana Pro',
    description: 'Google Gemini 3 Pro Image，适合高质量和复杂画面',
    route: '/v1/responses',
    spec: '1K / 2K / 4K',
    groupUsdPerImage: 0.25,
  },
  {
    id: 'nano-banana-2',
    name: 'Nano Banana 2',
    description: 'Google Gemini 3.1 Flash Image，速度和成本平衡',
    route: '/v1/responses',
    spec: '1K / 2K / 4K',
    groupUsdPerImage: 0.20,
  },
  {
    id: 'grok-imagine-image',
    name: 'Grok Imagine Image',
    description: 'xAI Imagine 图片生成模型的当前渠道名',
    route: '/v1/images/generations',
    spec: '1K / 2K',
    groupUsdPerImage: 0.10,
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

export function formatCny(value) {
  return `¥${value.toFixed(2)}`
}
