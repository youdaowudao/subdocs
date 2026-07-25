export const EXCHANGE_RATE = 7

const GPT_MODEL_IDS = [
  'gpt-5.6-sol',
  'gpt-5.6-terra',
  'gpt-5.6-luna',
  'gpt-5.5',
  'gpt-5.4',
  'gpt-5.4-mini',
]

const ANTHROPIC_MAIN_MODEL_IDS = [
  'claude-fable-5',
  'claude-haiku-4-5-20251001',
  'claude-opus-4-5-20251101',
  'claude-opus-4-6',
  'claude-opus-4-7',
  'claude-opus-4-8',
  'claude-opus-5',
  'claude-sonnet-4-6',
  'claude-sonnet-5',
]

const CC_MAX_MODEL_IDS = [
  ...ANTHROPIC_MAIN_MODEL_IDS.slice(0, 7),
  'claude-sonnet-4-5-20250929',
  'claude-sonnet-4-6',
  'claude-sonnet-5',
]

const OPENAI_ICON = '<path fill="currentColor" d="M22.282 9.821a6 6 0 0 0-.516-4.91a6.05 6.05 0 0 0-6.51-2.9A6.065 6.065 0 0 0 4.981 4.18a6 6 0 0 0-3.998 2.9a6.05 6.05 0 0 0 .743 7.097a5.98 5.98 0 0 0 .51 4.911a6.05 6.05 0 0 0 6.515 2.9A6 6 0 0 0 13.26 24a6.06 6.06 0 0 0 5.772-4.206a6 6 0 0 0 3.997-2.9a6.06 6.06 0 0 0-.747-7.073M13.26 22.43a4.48 4.48 0 0 1-2.876-1.04l.141-.081l4.779-2.758a.8.8 0 0 0 .392-.681v-6.737l2.02 1.168a.07.07 0 0 1 .038.052v5.583a4.504 4.504 0 0 1-4.494 4.494M3.6 18.304a4.47 4.47 0 0 1-.535-3.014l.142.085l4.783 2.759a.77.77 0 0 0 .78 0l5.843-3.369v2.332a.08.08 0 0 1-.033.062L9.74 19.95a4.5 4.5 0 0 1-6.14-1.646M2.34 7.896a4.5 4.5 0 0 1 2.366-1.973V11.6a.77.77 0 0 0 .388.677l5.815 3.354l-2.02 1.168a.08.08 0 0 1-.071 0l-4.83-2.786A4.504 4.504 0 0 1 2.34 7.872zm16.597 3.855l-5.833-3.387L15.119 7.2a.08.08 0 0 1 .071 0l4.83 2.791a4.494 4.494 0 0 1-.676 8.105v-5.678a.79.79 0 0 0-.407-.667m2.01-3.023l-.141-.085l-4.774-2.782a.78.78 0 0 0-.785 0L9.409 9.23V6.897a.07.07 0 0 1 .028-.061l4.83-2.787a4.5 4.5 0 0 1 6.68 4.66zm-12.64 4.135l-2.02-1.164a.08.08 0 0 1-.038-.057V6.075a4.5 4.5 0 0 1 7.375-3.453l-.142.08L8.704 5.46a.8.8 0 0 0-.393.681zm1.097-2.365l2.602-1.5l2.607 1.5v2.999l-2.597 1.5l-2.607-1.5Z"/>'
const ANTHROPIC_ICON = '<path fill="currentColor" d="M17.304 3.541h-3.672l6.696 16.918H24Zm-10.608 0L0 20.459h3.744l1.37-3.553h7.005l1.369 3.553h3.744L10.536 3.541Zm-.371 10.223L8.616 7.82l2.291 5.945Z"/>'
const X_ICON = '<path fill="currentColor" d="M14.234 10.162L22.977 0h-2.072l-7.591 8.824L7.251 0H.258l9.168 13.343L.258 24H2.33l8.016-9.318L16.749 24h6.993zm-2.837 3.299l-.929-1.329L3.076 1.56h3.182l5.965 8.532l.929 1.329l7.754 11.09h-3.182z"/>'

export const TEXT_GROUPS = [
  {
    id: 'pro-plus',
    name: 'GPT Plus 特惠分组（最近不稳定）',
    multiplier: 0.12,
    description: '低价入口，最近不稳定',
    modelIds: GPT_MODEL_IDS,
  },
  {
    id: 'gpt-0.18',
    name: 'GPT 日常分组',
    multiplier: 0.18,
    description: '适合日常对话、普通代码和大多数任务',
    modelIds: GPT_MODEL_IDS,
  },
  {
    id: 'full',
    name: 'GPT 正价 Pro 满血分组',
    multiplier: 0.28,
    description: '完整能力，适合重要任务',
    modelIds: GPT_MODEL_IDS,
  },
  {
    id: 'anthropic-main',
    name: '主力分组',
    multiplier: 0.4,
    description: '写作推荐 Opus 4.5，复杂架构设计推荐 Opus 4.8',
    modelIds: ANTHROPIC_MAIN_MODEL_IDS,
  },
  {
    id: 'anthropic-max',
    name: 'CC MAX 满血版本',
    multiplier: 1.9,
    description: '满血高性能档，价格较高，重大任务使用',
    modelIds: CC_MAX_MODEL_IDS,
  },
  {
    id: 'grok-4.5',
    name: 'Grok 4.5 分组',
    multiplier: 0.1,
    description: '速度比 GPT 日常分组更快，风控相对低，支持实时搜索和工具调用',
    modelIds: ['grok-4.5'],
  },
]

export const MODEL_CATEGORIES = [
  {
    id: 'gpt',
    name: 'GPT',
    iconSvg: OPENAI_ICON,
    kind: 'text',
    groupIds: ['pro-plus', 'gpt-0.18', 'full'],
    defaultGroupId: 'gpt-0.18',
  },
  {
    id: 'anthropic',
    name: 'Anthropic',
    iconSvg: ANTHROPIC_ICON,
    kind: 'text',
    groupIds: ['anthropic-main', 'anthropic-max'],
  },
  {
    id: 'grok',
    name: 'Grok',
    iconSvg: X_ICON,
    kind: 'text',
    groupIds: ['grok-4.5'],
  },
  {
    id: 'image',
    name: '生图',
    mark: '图',
    kind: 'image',
    groupIds: [],
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
  {
    id: 'claude-fable-5',
    name: 'Claude Fable 5',
    description: 'Anthropic 高端模型，适合复杂推理和长上下文任务',
    officialUsd: { input: 10, output: 50, cachedInput: 1 },
  },
  {
    id: 'claude-haiku-4-5-20251001',
    name: 'Claude Haiku 4.5',
    description: 'Anthropic 快速模型，适合日常任务和批量处理',
    officialUsd: { input: 1, output: 5, cachedInput: 0.1 },
  },
  {
    id: 'claude-opus-4-5-20251101',
    name: 'Claude Opus 4.5',
    description: 'Anthropic 高质量推理模型',
    officialUsd: { input: 5, output: 25, cachedInput: 0.5 },
  },
  {
    id: 'claude-opus-4-6',
    name: 'Claude Opus 4.6',
    description: 'Anthropic 复杂推理和高难度任务模型',
    officialUsd: { input: 5, output: 25, cachedInput: 0.5 },
  },
  {
    id: 'claude-opus-4-7',
    name: 'Claude Opus 4.7',
    description: 'Anthropic 高性能推理模型',
    officialUsd: { input: 5, output: 25, cachedInput: 0.5 },
  },
  {
    id: 'claude-opus-4-8',
    name: 'Claude Opus 4.8',
    description: 'Anthropic 高性能推理模型',
    officialUsd: { input: 5, output: 25, cachedInput: 0.5 },
  },
  {
    id: 'claude-opus-5',
    name: 'Claude Opus 5',
    description: 'Anthropic 满血推理模型，适合重大任务',
    officialUsd: { input: 5, output: 25, cachedInput: 0.5 },
  },
  {
    id: 'claude-sonnet-4-5-20250929',
    name: 'Claude Sonnet 4.5',
    description: 'Anthropic 均衡型模型，适合代码和综合任务',
    officialUsd: { input: 3, output: 15, cachedInput: 0.3 },
  },
  {
    id: 'claude-sonnet-4-6',
    name: 'Claude Sonnet 4.6',
    description: 'Anthropic 均衡型模型，适合代码和日常工作',
    officialUsd: { input: 3, output: 15, cachedInput: 0.3 },
  },
  {
    id: 'claude-sonnet-5',
    name: 'Claude Sonnet 5',
    description: 'Anthropic 新一代均衡模型，适合代码和长任务',
    officialUsd: { input: 3, output: 15, cachedInput: 0.3 },
  },
  {
    id: 'grok-4.5',
    name: 'Grok 4.5',
    description: '速度比 GPT 日常分组更快，风控相对低，支持实时搜索和工具调用',
    officialUsd: { input: 2, output: 6, cachedInput: 0.2 },
  },
]

export const IMAGE_GROUP = {
  id: 'image',
  name: '生图分组',
  description: '图片模型按当前分组默认价计费，单位为人民币 / 张',
}

export const IMAGE_MODELS = [
  {
    id: 'gpt-image-1k-th',
    name: 'GPT Image 1K',
    description: '低成本 1K 图片生成，适合草图和快速测试',
    route: '/v1/images/generations',
    spec: '1K',
    groupCnyPerImage: 0.03,
  },
  {
    id: 'gpt-image-2',
    name: 'GPT Image 2',
    description: '通用生图与改图，适合日常图片任务',
    route: '/v1/images/generations',
    spec: '按尺寸 / 画质',
    groupCnyPerImage: 0.05,
  },
  {
    id: 'gpt-image-2-4k',
    name: 'GPT Image 2 4K',
    description: '高分辨率图片生成，适合成品图和精细画面',
    route: '/v1/images/generations',
    spec: '4K',
    groupCnyPerImage: 0.08,
  },
  {
    id: 'gpt-image-1k-adobe',
    name: 'GPT Image 1K Adobe',
    description: '1K 竖图档，适合头像、封面小图和轻量测试',
    route: '/v1/images/generations',
    spec: '1K',
    groupCnyPerImage: 0.08,
  },
  {
    id: 'gpt-image-2k-adobe',
    name: 'GPT Image 2K Adobe',
    description: '2K 竖图档，适合更清晰的海报和社媒配图',
    route: '/v1/images/generations',
    spec: '2K',
    groupCnyPerImage: 0.15,
  },
  {
    id: 'gpt-image-4k-adobe',
    name: 'GPT Image 4K Adobe',
    description: '4K 竖图档，适合高清海报和大幅画面',
    route: '/v1/images/generations',
    spec: '4K',
    groupCnyPerImage: 0.20,
  },
  {
    id: 'gpt-image-2-adobe',
    name: 'GPT Image 2 Adobe',
    description: '通用图片生成档，适合常规出图和改图任务',
    route: '/v1/images/generations',
    spec: '按尺寸 / 画质',
    groupCnyPerImage: 0.12,
  },
  {
    id: 'gpt-image-4k-ys',
    name: 'GPT Image 4K YS',
    description: '高分辨率图片生成，适合高清成品图',
    route: '/v1/images/generations',
    spec: '4K',
    groupCnyPerImage: 0.20,
  },
  {
    id: 'nano-banana-pro',
    name: 'Nano Banana Pro',
    description: '高质量图片生成，适合复杂画面、细节和成品图',
    route: '/v1/responses',
    spec: '1K / 2K / 4K',
    groupCnyPerImage: 0.25,
  },
  {
    id: 'nano-banana-2',
    name: 'Nano Banana 2',
    description: '快速图片生成，适合日常出图和成本平衡',
    route: '/v1/responses',
    spec: '1K / 2K / 4K',
    groupCnyPerImage: 0.20,
  },
  {
    id: 'grok-imagine-image',
    name: 'Grok Imagine Image',
    description: '快速创意出图，适合轻量测试和多版本尝试',
    route: '/v1/images/generations',
    spec: '1K / 2K',
    groupCnyPerImage: 0.10,
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

export function getTextModelsForGroup(groupId) {
  const group = TEXT_GROUPS.find((item) => item.id === groupId)
  if (!group) return []

  const modelMap = new Map(TEXT_MODELS.map((model) => [model.id, model]))
  return group.modelIds.map((modelId) => modelMap.get(modelId)).filter(Boolean)
}

export function calculateImagePriceCny(cnyPerImage) {
  return Number(cnyPerImage.toFixed(2))
}

export function getEquivalentDiscount(multiplier) {
  return `${((multiplier / EXCHANGE_RATE) * 10).toFixed(1)}折`
}

export function formatCny(value) {
  return `¥${value.toFixed(2)}`
}
