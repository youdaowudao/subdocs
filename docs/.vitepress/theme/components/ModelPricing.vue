<script setup>
import { computed, ref } from 'vue'
import {
  EXCHANGE_RATE,
  IMAGE_GROUP,
  IMAGE_MODELS,
  TEXT_GROUPS,
  TEXT_MODELS,
  calculateTextPrice,
  formatCny,
  getEquivalentDiscount,
} from './model-pricing-data.mjs'

const exampleTextOfficialUsd = { input: 5, output: 30, cachedInput: 0.5 }

const activeCategory = ref('text')
const activeGroupId = ref(TEXT_GROUPS[0].id)
const priceMode = ref('group')
const copiedModel = ref('')

const activeGroup = computed(
  () => TEXT_GROUPS.find((group) => group.id === activeGroupId.value) ?? TEXT_GROUPS[0],
)

const textRows = computed(() =>
  TEXT_MODELS.map((model) => ({
    ...model,
    prices: calculateTextPrice(model.officialUsd, activeGroup.value.multiplier),
  })),
)

const pricingRuleExample = computed(() => {
  if (activeCategory.value !== 'text') {
    return '示例：GPT Image 2 当前分组价 $0.05 / 张'
  }

  const examplePrice = calculateTextPrice(
    exampleTextOfficialUsd,
    activeGroup.value.multiplier,
  )

  return `示例：GPT-5.5 输入官方 ¥35.00，${activeGroup.value.name} 输入价 ${formatCny(examplePrice.group.input)}`
})

const copyModelId = async (modelId) => {
  if (!navigator?.clipboard) return
  await navigator.clipboard.writeText(modelId)
  copiedModel.value = modelId
  window.setTimeout(() => {
    if (copiedModel.value === modelId) copiedModel.value = ''
  }, 1400)
}

const formatUsd = (value) => `$${value.toFixed(2)}`
</script>

<template>
  <main class="model-pricing-page">
    <header class="model-pricing-heading">
      <div>
        <h1>模型价格</h1>
      </div>
    </header>

    <nav class="model-category-tabs" aria-label="模型类型">
      <button
        type="button"
        :class="{ 'is-active': activeCategory === 'text' }"
        :aria-pressed="activeCategory === 'text'"
        @click="activeCategory = 'text'"
      >
        <span class="model-category-mark model-category-mark--gpt">G</span>
        GPT 模型
      </button>
      <button
        type="button"
        :class="{ 'is-active': activeCategory === 'image' }"
        :aria-pressed="activeCategory === 'image'"
        @click="activeCategory = 'image'"
      >
        <span class="model-category-mark model-category-mark--image">图</span>
        图片生成
      </button>
    </nav>

    <section class="pricing-rule" aria-label="计价规则">
      <div>
        <strong>计价规则</strong>
        <span>官方美元价格按 $1 = ¥{{ EXCHANGE_RATE }} 换算</span>
        <span v-if="activeCategory === 'text'">分组价格 = 官方美元价格 × 分组倍率</span>
        <span v-else>生图分组价格按模型默认美元价计费</span>
      </div>
      <span class="pricing-rule-example">
        {{ pricingRuleExample }}
      </span>
    </section>

    <section class="pricing-panel">
      <header class="pricing-panel-header">
        <div>
          <span class="pricing-panel-icon" aria-hidden="true">¥</span>
          <h2>价格列表</h2>
        </div>
        <div class="price-mode-wrap">
          <span v-if="activeCategory === 'text'">{{ priceMode === 'group' ? '分组价已按人民币计算' : '官方价按固定汇率换算' }}</span>
          <span v-else>分组价按美元 / 张显示</span>
          <div v-if="activeCategory === 'text'" class="price-mode-switch" role="group" aria-label="价格类型">
            <button
              type="button"
              :class="{ 'is-active': priceMode === 'group' }"
              :aria-pressed="priceMode === 'group'"
              @click="priceMode = 'group'"
            >分组价格</button>
            <button
              type="button"
              :class="{ 'is-active': priceMode === 'official' }"
              :aria-pressed="priceMode === 'official'"
              @click="priceMode = 'official'"
            >官方价格</button>
          </div>
        </div>
      </header>

      <div v-if="activeCategory === 'text'" class="pricing-content">
        <div v-if="priceMode === 'group'" class="pricing-groups" aria-label="选择分组">
          <button
            v-for="group in TEXT_GROUPS"
            :key="group.id"
            type="button"
            :class="{ 'is-active': activeGroupId === group.id }"
            :aria-pressed="activeGroupId === group.id"
            @click="activeGroupId = group.id"
          >
            <span class="pricing-group-title">
              <strong>{{ group.name }}</strong>
              <em>{{ getEquivalentDiscount(group.multiplier) }}</em>
            </span>
            <span>{{ group.multiplier }} 倍率 · {{ group.description }}</span>
          </button>
        </div>

        <div class="pricing-description">
          <template v-if="priceMode === 'group'">
            <strong>分组介绍：</strong>
            <span>{{ activeGroup.name }}，{{ activeGroup.description }}。</span>
          </template>
          <template v-else>
            <strong>官方价格：</strong>
            <span>按 $1 = ¥{{ EXCHANGE_RATE }} 折算成人民币，仅用于和分组价格对比。</span>
          </template>
        </div>

        <div class="pricing-table-scroll">
          <table class="pricing-table">
            <thead>
              <tr>
                <th scope="col">模型 ID</th>
                <th scope="col">输入价格</th>
                <th scope="col">输出价格</th>
                <th scope="col">缓存读取</th>
                <th scope="col">输入 + 输出合计</th>
                <th scope="col">节省幅度</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="model in textRows" :key="model.id">
                <td>
                  <div class="model-id-cell">
                    <div>
                      <strong>{{ model.id }}</strong>
                      <span>{{ model.description }}</span>
                    </div>
                    <button
                      type="button"
                      class="copy-model-button"
                      :aria-label="`复制 ${model.id}`"
                      :title="copiedModel === model.id ? '已复制' : '复制模型 ID'"
                      @click="copyModelId(model.id)"
                    >
                      <span aria-hidden="true"></span>
                    </button>
                  </div>
                </td>
                <td v-for="field in ['input', 'output', 'cachedInput', 'total']" :key="field">
                  <template v-if="priceMode === 'group'">
                    <strong class="group-price">{{ formatCny(model.prices.group[field]) }}</strong>
                    <span class="price-unit">/ 1M tokens</span>
                    <del>官方 {{ formatCny(model.prices.official[field]) }}</del>
                  </template>
                  <template v-else>
                    <strong class="official-price">{{ formatCny(model.prices.official[field]) }}</strong>
                    <span class="price-unit">/ 1M tokens</span>
                    <span class="official-usd">
                      ${{ field === 'total'
                        ? (model.officialUsd.input + model.officialUsd.output).toFixed(2)
                        : model.officialUsd[field].toFixed(3).replace(/0+$/, '').replace(/\.$/, '') }}
                    </span>
                  </template>
                </td>
                <td>
                  <span v-if="priceMode === 'group'" class="saving-badge">
                    省 {{ Math.round((1 - activeGroup.multiplier / EXCHANGE_RATE) * 100) }}%
                  </span>
                  <span v-else class="official-label">官方基准</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-else class="pricing-content">
        <div v-if="priceMode === 'group'" class="pricing-groups pricing-groups--image">
          <div class="pricing-group-static is-active">
            <span class="pricing-group-title">
              <strong>{{ IMAGE_GROUP.name }}</strong>
              <em>按模型计价</em>
            </span>
            <span>{{ IMAGE_GROUP.description }}</span>
          </div>
        </div>

        <div class="pricing-description">
          <strong>绘图价格：</strong>
          <span>当前分组按模型设置默认美元价格，图片请求按张计费。</span>
        </div>

        <div class="pricing-table-scroll">
          <table class="pricing-table pricing-table--image">
            <thead>
              <tr>
                <th scope="col">模型 ID</th>
                <th scope="col">模型介绍</th>
                <th scope="col">接口 / 规格</th>
                <th scope="col">当前分组价</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="model in IMAGE_MODELS" :key="model.id">
                <td>
                  <div class="model-id-cell">
                    <div>
                      <strong v-if="model.id === 'gpt-image-2'">{{ model.id }}</strong>
                      <span v-else class="image-model-id">{{ model.id }}</span>
                      <span v-if="model.id === 'gpt-image-2'">推荐日常使用</span>
                    </div>
                    <button
                      type="button"
                      class="copy-model-button"
                      :aria-label="`复制 ${model.id}`"
                      :title="copiedModel === model.id ? '已复制' : '复制模型 ID'"
                      @click="copyModelId(model.id)"
                    ><span aria-hidden="true"></span></button>
                  </div>
                </td>
                <td><span class="model-description">{{ model.description }}</span></td>
                <td>
                  <strong class="table-plain-value">{{ model.route }}</strong>
                  <span class="table-subvalue">{{ model.spec }}</span>
                </td>
                <td>
                  <strong class="group-price">{{ formatUsd(model.groupUsdPerImage) }}</strong>
                  <span class="price-unit">/ 张</span>
                  <span class="table-subvalue">当前分组默认价</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <p class="pricing-footnote">
      <span v-if="activeCategory === 'text'">文本模型官方价格按当前公开标准价和固定汇率换算。</span>
      <span v-else>生图分组价格按当前模型默认美元价显示。</span>
      页面价格用于说明和对比，实际扣费以后台定价配置和调用记录为准。
    </p>
  </main>
</template>

<style>
.VPDoc:has(.model-pricing-page) {
  padding: 48px var(--site-shell-inset, 32px) 56px 16px !important;
}

.VPDoc:has(.model-pricing-page) .container,
.VPDoc:has(.model-pricing-page) .content-container {
  width: 100% !important;
  max-width: none !important;
}

.VPDoc:has(.model-pricing-page) .container {
  padding-top: 32px !important;
}

.VPDoc:has(.model-pricing-page) .vp-doc {
  font-size: 15px;
  line-height: 1.6;
}

.VPDoc:has(.model-pricing-page) .prev-next {
  display: none;
}

.model-pricing-page {
  width: 100%;
  color: var(--vp-c-text-1);
  font-family: var(--vp-font-family-base);
  letter-spacing: 0;
}

.model-pricing-page button {
  font-family: inherit;
  letter-spacing: 0;
}

.model-pricing-heading {
  display: flex;
  min-height: 0;
  align-items: flex-start;
  justify-content: space-between;
  padding: 0 0 24px;
}

.model-pricing-heading h1 {
  margin: 0 0 16px;
  border: 0;
  color: var(--vp-c-text-1);
  font-family: var(--vp-font-family-base);
  font-size: 38px;
  font-weight: 750;
  line-height: 1.28;
}

.model-category-tabs {
  display: flex;
  min-height: 68px;
  align-items: center;
  gap: 8px;
  padding: 8px;
  border: 1px solid var(--site-line);
  border-radius: 8px;
  background: var(--site-surface);
  box-shadow: 0 4px 14px rgba(108, 63, 31, 0.035);
}

.model-category-tabs button {
  display: inline-flex;
  min-width: 150px;
  height: 50px;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 0 20px;
  border: 1px solid transparent;
  border-radius: 7px;
  background: transparent;
  color: var(--vp-c-text-2);
  font-size: 18px;
  font-weight: 560;
  cursor: pointer;
}

.model-category-tabs button:hover {
  background: #faf8f5;
  color: #9a4f16;
}

.model-category-tabs button.is-active {
  border-color: #e58b48;
  background: #fffaf6;
  color: #9a4f16;
}

.model-category-mark {
  display: inline-flex;
  width: 25px;
  height: 25px;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: #fff;
  font-size: 13px;
  font-weight: 800;
}

.model-category-mark--gpt { background: #33271f; }
.model-category-mark--image { background: #da6b35; }

.pricing-rule {
  display: flex;
  min-height: 48px;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  margin-top: 16px;
  padding: 10px 20px;
  border: 1px solid var(--site-line);
  border-radius: 8px;
  background: var(--site-surface);
  color: var(--vp-c-text-2);
  font-size: 14px;
}

.pricing-rule > div {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 18px;
}

.pricing-rule strong {
  color: var(--vp-c-text-1);
  font-size: 14px;
}

.pricing-rule-example {
  flex: 0 1 auto;
  color: var(--vp-c-text-3);
  text-align: right;
}

.pricing-panel {
  margin-top: 16px;
  border: 1px solid var(--site-line);
  border-radius: 8px;
  background: var(--site-surface);
  box-shadow: 0 5px 18px rgba(108, 63, 31, 0.045);
  overflow: hidden;
}

.pricing-panel-header {
  display: flex;
  min-height: 66px;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  padding: 14px 20px;
  border-bottom: 1px solid var(--site-line);
}

.pricing-panel-header > div:first-child {
  display: flex;
  align-items: center;
  gap: 10px;
}

.pricing-panel-header h2 {
  margin: 0;
  padding: 0;
  border: 0;
  color: var(--vp-c-text-1);
  font-size: 21px;
  font-weight: 750;
  line-height: 1.3;
}

.pricing-panel-icon {
  display: inline-flex;
  width: 24px;
  height: 24px;
  align-items: center;
  justify-content: center;
  border: 1.5px solid #9a765c;
  border-radius: 50%;
  color: #765941;
  font-size: 13px;
  font-weight: 800;
}

.price-mode-wrap {
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--vp-c-text-3);
  font-size: 13px;
}

.price-mode-switch {
  display: inline-flex;
  padding: 3px;
  border: 1px solid var(--site-line);
  border-radius: 18px;
  background: #f8eee2;
}

.price-mode-switch button {
  min-width: 76px;
  height: 28px;
  padding: 0 12px;
  border: 0;
  border-radius: 14px;
  background: transparent;
  color: var(--vp-c-text-2);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.price-mode-switch button.is-active {
  background: #a64b0d;
  box-shadow: 0 1px 3px rgba(75, 37, 12, 0.18);
  color: #fff;
}

.pricing-content {
  padding: 20px;
}

.pricing-groups {
  display: grid;
  grid-template-columns: repeat(3, minmax(220px, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}

.pricing-groups > button,
.pricing-group-static {
  display: flex;
  min-height: 82px;
  flex-direction: column;
  justify-content: center;
  gap: 6px;
  padding: 14px 16px;
  border: 1px solid var(--site-line);
  border-radius: 8px;
  background: rgba(255, 252, 247, 0.94);
  color: var(--vp-c-text-2);
  font-size: 14px;
  text-align: left;
}

.pricing-groups > button { cursor: pointer; }

.pricing-groups > button:hover {
  border-color: #e4a06f;
  background: #fffaf7;
}

.pricing-groups > button.is-active,
.pricing-group-static.is-active {
  border-color: #ee8a43;
  background: #fffaf6;
  box-shadow: inset 0 0 0 1px rgba(238, 138, 67, 0.08);
}

.pricing-group-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.pricing-group-title strong {
  color: var(--vp-c-text-1);
  font-size: 17px;
  font-weight: 750;
}

.pricing-group-title em {
  padding: 3px 9px;
  border-radius: 12px;
  background: #ffe2d3;
  color: #a84c14;
  font-size: 13px;
  font-style: normal;
  font-weight: 800;
  line-height: 1.4;
}

.pricing-groups--image {
  grid-template-columns: minmax(300px, 380px);
}

.pricing-description {
  display: flex;
  min-height: 48px;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
  padding: 10px 16px;
  border: 1px solid #f2d8ca;
  border-radius: 8px;
  background: #fffaf7;
  color: var(--vp-c-text-2);
  font-size: 15px;
}

.pricing-description strong {
  flex: 0 0 auto;
  color: #9f4a17;
  font-weight: 750;
}

.pricing-table-scroll {
  border: 1px solid var(--site-line);
  border-radius: 8px;
  overflow-x: auto;
}

.model-pricing-page .pricing-table {
  width: 100%;
  min-width: 1040px;
  margin: 0;
  border: 0;
  border-collapse: collapse;
  border-radius: 0;
  font-size: 14px;
  table-layout: fixed;
}

.model-pricing-page .pricing-table th,
.model-pricing-page .pricing-table td {
  border: 0;
  border-bottom: 1px solid var(--site-line);
  text-align: left;
  vertical-align: middle;
}

.model-pricing-page .pricing-table th {
  height: 48px;
  padding: 0 16px;
  background: #f8eee2;
  color: var(--vp-c-text-2);
  font-size: 14px;
  font-weight: 650;
}

.model-pricing-page .pricing-table td {
  height: 86px;
  padding: 12px 16px;
  background: rgba(255, 252, 247, 0.94);
  color: var(--vp-c-text-1);
}

.model-pricing-page .pricing-table tbody tr:last-child td { border-bottom: 0; }
.model-pricing-page .pricing-table th:first-child { width: 23%; }
.model-pricing-page .pricing-table th:nth-child(2),
.model-pricing-page .pricing-table th:nth-child(3),
.model-pricing-page .pricing-table th:nth-child(4) { width: 15%; }
.model-pricing-page .pricing-table th:nth-child(5) { width: 18%; }
.model-pricing-page .pricing-table th:nth-child(6) { width: 14%; }

.model-pricing-page .pricing-table--image {
  min-width: 980px;
}

.model-pricing-page .pricing-table--image th:first-child { width: 24%; }
.model-pricing-page .pricing-table--image th:nth-child(2) { width: 34%; }
.model-pricing-page .pricing-table--image th:nth-child(3) { width: 20%; }
.model-pricing-page .pricing-table--image th:nth-child(4) { width: 22%; }

.model-id-cell {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.model-id-cell > div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 3px;
}

.model-id-cell strong {
  color: var(--vp-c-text-1);
  font-size: 15px;
  font-weight: 750;
}

.model-id-cell > div > span {
  color: var(--vp-c-text-3);
  font-size: 13px;
  line-height: 1.35;
}

.model-id-cell .image-model-id {
  color: var(--vp-c-text-1);
  font-size: 15px;
  font-weight: 600;
}

.copy-model-button {
  position: relative;
  width: 24px;
  height: 24px;
  flex: 0 0 24px;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
}

.copy-model-button::before,
.copy-model-button span {
  content: '';
  position: absolute;
  width: 8px;
  height: 8px;
  border: 1.5px solid #ad9a89;
  border-radius: 2px;
}

.copy-model-button::before { top: 6px; left: 7px; }
.copy-model-button span { top: 9px; left: 10px; background: #fffaf4; }
.copy-model-button:hover::before,
.copy-model-button:hover span { border-color: #a64b0d; }

.group-price,
.official-price {
  color: #ad500f;
  font-size: 17px;
  font-weight: 800;
  white-space: nowrap;
}

.official-price { color: var(--vp-c-text-1); }

.price-unit {
  margin-left: 3px;
  color: var(--vp-c-text-3);
  font-size: 11px;
  white-space: nowrap;
}

.model-pricing-page .pricing-table del,
.official-usd {
  display: block;
  margin-top: 3px;
  color: #aa9b8f;
  font-size: 11px;
  line-height: 1.35;
  text-decoration-thickness: 1px;
}

.official-usd { text-decoration: none; }

.saving-badge,
.official-label {
  display: inline-flex;
  min-height: 28px;
  align-items: center;
  justify-content: center;
  padding: 4px 11px;
  border-radius: 15px;
  background: #eaf9ef;
  color: #239653;
  font-size: 13px;
  font-weight: 800;
  white-space: nowrap;
}

.official-label {
  background: #f3e9de;
  color: var(--vp-c-text-2);
}

.table-plain-value {
  color: var(--vp-c-text-1);
  font-size: 15px;
  font-weight: 650;
}

.table-subvalue,
.model-description {
  display: block;
  color: var(--vp-c-text-3);
  font-size: 12px;
  line-height: 1.5;
}

.model-description {
  color: var(--vp-c-text-2);
}

.pricing-footnote {
  margin: 12px 2px 0 !important;
  color: var(--vp-c-text-3) !important;
  font-size: 12px !important;
  line-height: 1.6 !important;
}

.dark .model-pricing-page { color: #f4eee5; }
.dark .model-pricing-heading h1,
.dark .pricing-panel-header h2,
.dark .pricing-group-title strong,
.dark .model-id-cell strong,
.dark .table-plain-value { color: #f4eee5; }
.dark .model-category-tabs,
.dark .pricing-rule,
.dark .pricing-panel,
.dark .pricing-groups > button,
.dark .pricing-group-static,
.dark .model-pricing-page .pricing-table td { background: #211f1d; border-color: #3a3530; }
.dark .model-category-tabs,
.dark .pricing-rule,
.dark .pricing-panel,
.dark .pricing-table-scroll { border-color: #3a3530; }
.dark .model-pricing-page .pricing-table th { background: #2a2724; color: #c2b9b0; }
.dark .pricing-description { border-color: #5a3b29; background: #2b211b; }
.dark .copy-model-button span { background: #211f1d; }

@media (max-width: 1100px) {
  .price-mode-wrap > span,
  .pricing-rule-example { display: none; }
}

@media (max-width: 768px) {
  .VPDoc:has(.model-pricing-page) { padding: 32px 16px 40px !important; }
  .VPDoc:has(.model-pricing-page) .container { padding-top: 22px !important; }
  .model-pricing-heading { min-height: 0; padding-bottom: 20px; }
  .model-pricing-heading h1 { margin-bottom: 16px; font-size: 30px; }
  .model-category-tabs { min-height: 58px; }
  .model-category-tabs button { min-width: 0; height: 42px; flex: 1; padding: 0 10px; font-size: 15px; }
  .model-category-mark { width: 22px; height: 22px; font-size: 11px; }
  .pricing-rule { align-items: flex-start; }
  .pricing-rule > div { gap: 4px 14px; }
  .pricing-rule > div span { width: 100%; }
  .pricing-panel-header { align-items: flex-start; flex-direction: column; gap: 10px; }
  .price-mode-wrap { width: 100%; }
  .price-mode-switch { width: 100%; }
  .price-mode-switch button { flex: 1; }
  .pricing-content { padding: 14px; }
  .pricing-groups,
  .pricing-groups--image { grid-template-columns: 1fr; }
  .pricing-description { align-items: flex-start; flex-direction: column; gap: 2px; }
  .model-pricing-page .pricing-table { min-width: 980px; }
  .model-pricing-page .pricing-table--image { min-width: 980px; }
}
</style>
