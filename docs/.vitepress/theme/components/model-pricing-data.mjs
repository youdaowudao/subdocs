export const EXCHANGE_RATE = 7

const GPT_MODEL_IDS = [
  'gpt-5.6-sol',
  'gpt-5.6-terra',
  'gpt-5.6-luna',
  'gpt-5.5',
  'gpt-5.4',
  'gpt-5.4-mini',
]

const GEMINI_MODEL_IDS = [
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
const CLAUDE_CODE_ICON = '<path fill="#D97757" fill-rule="nonzero" d="M4.709 15.955l4.72-2.647.08-.23-.08-.128H9.2l-.79-.048-2.698-.073-2.339-.097-2.266-.122-.571-.121L0 11.784l.055-.352.48-.321.686.06 1.52.103 2.278.158 1.652.097 2.449.255h.389l.055-.157-.134-.098-.103-.097-2.358-1.596-2.552-1.688-1.336-.972-.724-.491-.364-.462-.158-1.008.656-.722.881.06.225.061.893.686 1.908 1.476 2.491 1.833.365.304.145-.103.019-.073-.164-.274-1.355-2.446-1.446-2.49-.644-1.032-.17-.619a2.97 2.97 0 0 1-.104-.729L6.283.134 6.696 0l.996.134.42.364.62 1.414 1.002 2.229 1.555 3.03.456.898.243.832.091.255h.158V9.01l.128-1.706.237-2.095.23-2.695.08-.76.376-.91.747-.492.584.28.48.685-.067.444-.286 1.851-.559 2.903-.364 1.942h.212l.243-.242.985-1.306 1.652-2.064.73-.82.85-.904.547-.431h1.033l.76 1.129-.34 1.166-1.064 1.347-.881 1.142-1.264 1.7-.79 1.36.073.11.188-.02 2.856-.606 1.543-.28 1.841-.315.833.388.091.395-.328.807-1.969.486-2.309.462-3.439.813-.042.03.049.061 1.549.146.662.036h1.622l3.02.225.79.522.474.638-.079.485-1.215.62-1.64-.389-3.829-.91-1.312-.329h-.182v.11l1.093 1.068 2.006 1.81 2.509 2.33.127.578-.322.455-.34-.049-2.205-1.657-.851-.747-1.926-1.62h-.128v.17l.444.649 2.345 3.521.122 1.08-.17.353-.608.213-.668-.122-1.374-1.925-1.415-2.167-1.143-1.943-.14.08-.674 7.254-.316.37-.729.28-.607-.461-.322-.747.322-1.476.389-1.924.315-1.53.286-1.9.17-.632-.012-.042-.14.018-1.434 1.967-2.18 2.945-1.726 1.845-.414.164-.717-.37.067-.662.401-.589 2.388-3.036 1.44-1.882.93-1.086-.006-.158h-.055L4.132 18.56l-1.13.146-.487-.456.061-.746.231-.243 1.908-1.312-.006.006z"/>'
const X_ICON = '<path fill="#141413" d="M14.234 10.162L22.977 0h-2.072l-7.591 8.824L7.251 0H.258l9.168 13.343L.258 24H2.33l8.016-9.318L16.749 24h6.993zm-2.837 3.299l-.929-1.329L3.076 1.56h3.182l5.965 8.532l.929 1.329l7.754 11.09h-3.182z"/>'
const GEMINI_ICON = '<path fill="#8E75B2" d="M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68q.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58a12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68q-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96q2.19.93 3.81 2.55t2.55 3.81"/>'

export const TEXT_GROUPS = [
  {
    id: 'pro-plus',
    name: 'GPT Plus 特惠分组（最近不稳定）',
    multiplier: 0.095,
    description: '低价入口，最近不稳定',
    modelIds: GPT_MODEL_IDS,
  },
  {
    id: 'gpt-0.18',
    name: 'GPT Pro / Plus 混池分组',
    multiplier: 0.15,
    description: '适合日常对话、普通代码和大多数任务',
    modelIds: GPT_MODEL_IDS,
  },
  {
    id: 'full',
    name: 'GPT 正价 Pro 满血分组',
    multiplier: 0.25,
    description: '完整能力，适合重要任务',
    modelIds: GPT_MODEL_IDS,
  },
  {
    id: 'anthropic-main',
    name: '主力分组',
    multiplier: 0.3,
    description: '写作推荐 Fable 5，复杂架构设计推荐 Opus 5',
    modelIds: ANTHROPIC_MAIN_MODEL_IDS,
  },
  {
    id: 'anthropic-max',
    name: 'CC MAX 满血版本',
    multiplier: 1.3,
    description: '满血高性能档，价格较高，重大任务使用',
    modelIds: CC_MAX_MODEL_IDS,
  },
  {
    id: 'grok-4.5',
    name: 'heavy号池',
    multiplier: 0.35,
    description: '速度比 GPT Pro / Plus 混池分组更快，风控相对低，支持实时搜索和工具调用',
    modelIds: ['grok-4.6', 'grok-4.5'],
  },
  {
    id: 'gemini-antigravity',
    name: 'Gemini 分组（反重力 Antigravity 反代）',
    multiplier: 0.25,
    description: '适合 Antigravity、代理式编程和 Gemini 模型测试',
    modelIds: GEMINI_MODEL_IDS,
  },
  {
    id: 'deepseek-v4-flash',
    name: 'DeepSeek V4 Flash 分组',
    multiplier: 0.4,
    currency: 'cny',
    description: 'V4 Flash 0731 正式版，适合代码、Agent 和长上下文任务',
    modelIds: ['deepseek-v4-flash'],
  },
  {
    id: 'domestic',
    name: '国产之光',
    multiplier: 0.2,
    currency: 'cny',
    description: '限制相对 GPT 更宽，可用于逆向等场景',
    modelIds: ['glm-5.2', 'LongCat-2.0'],
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
    iconSvg: CLAUDE_CODE_ICON,
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
    id: 'gemini',
    name: 'Gemini',
    iconSvg: GEMINI_ICON,
    kind: 'text',
    groupIds: ['gemini-antigravity'],
  },
  {
    id: 'deepseek',
    name: 'DeepSeek',
    mark: '深',
    kind: 'text',
    groupIds: ['deepseek-v4-flash'],
  },
  {
    id: 'domestic',
    name: 'GLM',
    mark: '中',
    kind: 'text',
    groupIds: ['domestic'],
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
    description: 'Anthropic 写作向模型，适合长文创作、文案润色和自然表达',
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
    id: 'grok-4.6',
    name: 'Grok 4.6',
    description: 'XAI最新模型，性能直逼OPUS 5跟GPT 5.6 SOL，限制低，速度快，当前非常火热。',
    officialUsd: { input: 2, output: 6, cachedInput: 0.5 },
  },
  {
    id: 'grok-4.5',
    name: 'Grok 4.5',
    description: '速度比 GPT 日常分组更快，风控相对低，支持实时搜索和工具调用',
    officialUsd: { input: 2, output: 6, cachedInput: 0.2 },
  },
  {
    id: 'gemini-3.7-flash',
    name: 'Gemini 3.7 Flash',
    description: '2026-08 发布，当前主推，适合代码、代理流程和多模态任务；首发价到 2026-12-31',
    officialUsd: { input: 0.75, output: 3.75, cachedInput: 0.075 },
    featured: true,
    featuredLabel: '主推',
  },
  {
    id: 'gemini-3.6-flash-tiered',
    name: 'Gemini 3.6 Flash Tiered',
    description: '2026-07 更新，3.6 Flash 分层入口，适合 Antigravity 高频代理任务',
    officialUsd: { input: 1.5, output: 7.5, cachedInput: 0.15 },
  },
  {
    id: 'gemini-3.6-flash',
    name: 'Gemini 3.6 Flash',
    description: '2026-07 更新，适合代码生成、多步代理流程和多模态任务',
    officialUsd: { input: 1.5, output: 7.5, cachedInput: 0.15 },
  },
  {
    id: 'gemini-3.5-flash',
    name: 'Gemini 3.5 Flash',
    description: '2026-05 更新，适合速度优先的代码任务、搜索和工具调用',
    officialUsd: { input: 1.5, output: 9, cachedInput: 0.15 },
  },
  {
    id: 'gemini-3.1-pro-preview',
    name: 'Gemini 3.1 Pro Preview',
    description: '2026-02 更新，适合复杂推理、长上下文和多模态分析',
    officialUsd: { input: 2, output: 12, cachedInput: 0.2 },
  },
  {
    id: 'gemini-3.1-flash-lite',
    name: 'Gemini 3.1 Flash-Lite',
    description: '低延迟低成本模型，适合高频轻量任务、分类和数据提取',
    officialUsd: { input: 0.25, output: 1.5, cachedInput: 0.025 },
  },
  {
    id: 'gemini-3.1-flash-lite-preview',
    name: 'Gemini 3.1 Flash-Lite Preview',
    description: '2026-03 更新，适合高频轻量任务和低成本批量处理',
    officialUsd: { input: 0.25, output: 1.5, cachedInput: 0.025 },
  },
  {
    id: 'gemini-3-pro-preview',
    name: 'Gemini 3 Pro Preview',
    description: '2025-11 更新，适合复杂推理、多模态理解和代码规划',
    officialUsd: { input: 2, output: 12, cachedInput: 0.2 },
  },
  {
    id: 'gemini-3-flash',
    name: 'Gemini 3 Flash',
    description: '3 系列 Flash 入口，适合速度、成本和代理能力平衡',
    officialUsd: { input: 0.5, output: 3, cachedInput: 0.05 },
  },
  {
    id: 'gemini-3-flash-preview',
    name: 'Gemini 3 Flash Preview',
    description: '2025-12 更新，适合多模态理解、代理编程和快速验证',
    officialUsd: { input: 0.5, output: 3, cachedInput: 0.05 },
  },
  {
    id: 'gemini-2.5-pro',
    name: 'Gemini 2.5 Pro',
    description: '2025-06 更新，适合复杂问题推理、代码分析和长任务',
    officialUsd: { input: 1.25, output: 10, cachedInput: 0.125 },
  },
  {
    id: 'gemini-2.5-flash',
    name: 'Gemini 2.5 Flash',
    description: '2025-06 更新，适合大规模处理、低延迟和高吞吐任务',
    officialUsd: { input: 0.3, output: 2.5, cachedInput: 0.03 },
  },
  {
    id: 'gemini-2.5-flash-lite',
    name: 'Gemini 2.5 Flash-Lite',
    description: '2025-07 更新，适合高频分类、简单提取和极低延迟场景',
    officialUsd: { input: 0.1, output: 0.4, cachedInput: 0.01 },
  },
  {
    id: 'deepseek-v4-flash',
    name: 'DeepSeek V4 Flash 0731',
    description: 'V4-Flash-0731 正式版，支持思考模式、工具调用和 Responses API',
    officialCny: { input: 1, output: 2, cachedInput: 0.02 },
  },
  {
    id: 'glm-5.2',
    name: 'GLM-5.2',
    description: '国产旗舰模型，适合复杂推理、代码和逆向分析场景',
    officialCny: { input: 8, output: 20, cachedInput: 2 },
  },
  {
    id: 'LongCat-2.0',
    name: 'LongCat-2.0',
    description: '国产长上下文模型，适合代码、代理任务和长流程处理',
    officialCny: { input: 2, output: 8, cachedInput: 0.04 },
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
    spec: '1K / 2K / 4K',
    groupCnyPerImage: 0.05,
    sizePricesCny: [
      { size: '1K', cnyPerImage: 0.04 },
      { size: '2K', cnyPerImage: 0.05 },
      { size: '4K', cnyPerImage: 0.08 },
    ],
  },
  {
    id: 'gpt-image-2-adobe',
    name: 'GPT Image 2 Adobe',
    description: '通用图片生成档，适合常规出图和改图任务',
    route: '/v1/images/generations',
    spec: '按尺寸 / 画质',
    groupCnyPerImage: 0.12,
    priceNote: '1/2/4k统一价',
  },
  {
    id: 'grok-imagine-image',
    name: 'Grok Imagine Image',
    description: '自动尺寸图片生成，适合快速创意出图和多版本尝试',
    route: '/v1/images/generations',
    spec: '自动尺寸',
    groupCnyPerImage: 0.10,
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
    groupCnyPerImage: 0.12,
  },
]

export function calculateTextPrice(officialPrice, multiplier, currency = 'usd') {
  const exchangeRate = currency === 'cny' ? 1 : EXCHANGE_RATE
  const official = {
    input: officialPrice.input * exchangeRate,
    output: officialPrice.output * exchangeRate,
    cachedInput: officialPrice.cachedInput * exchangeRate,
    total: (officialPrice.input + officialPrice.output) * exchangeRate,
  }

  const group = {
    input: officialPrice.input * multiplier,
    output: officialPrice.output * multiplier,
    cachedInput: officialPrice.cachedInput * multiplier,
    total: (officialPrice.input + officialPrice.output) * multiplier,
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

export function getEquivalentDiscount(multiplier, currency = 'usd') {
  const normalizedMultiplier = currency === 'cny' ? multiplier : multiplier / EXCHANGE_RATE
  return `${(normalizedMultiplier * 10).toFixed(1)}折`
}

export function getSavingsPercent(multiplier, currency = 'usd') {
  const normalizedMultiplier = currency === 'cny' ? multiplier : multiplier / EXCHANGE_RATE
  return Math.round((1 - normalizedMultiplier) * 100)
}

export function formatCny(value) {
  if (value > 0 && value < 0.01) {
    return `¥${value.toFixed(4)}`
  }

  return `¥${value.toFixed(2)}`
}
