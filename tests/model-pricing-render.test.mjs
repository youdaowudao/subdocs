import test from 'node:test'
import assert from 'node:assert/strict'
import { createServer } from 'vite'
import vue from '@vitejs/plugin-vue'
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

test('renders Haiku 5.5 once with both context prices in the same row', async () => {
  const server = await createServer({
    configFile: false,
    plugins: [vue()],
    server: { middlewareMode: true },
    appType: 'custom',
  })

  try {
    const { default: pricing } = await server.ssrLoadModule('/docs/.vitepress/theme/components/ModelPricing.vue')
    const expectedGroupPrices = new Map([
      ['anthropic-max', ['¥0.13', '¥0.65', '¥0.65', '¥3.25', '¥0.013', '¥0.065', '¥0.78', '¥3.90']],
      ['anthropic-max-external', ['¥0.14', '¥0.72', '¥0.72', '¥3.63', '¥0.0145', '¥0.0725', '¥0.87', '¥4.35']],
    ])
    const expectedOfficialPrices = ['¥0.70', '¥3.50', '¥3.50', '¥17.50', '¥0.07', '¥0.35', '¥4.20', '¥21.00']

    for (const [groupId, expectedPrices] of expectedGroupPrices) {
      for (const priceMode of ['group', 'official']) {
        const component = {
          ...pricing,
          setup(props, context) {
            const state = pricing.setup(props, context)
            state.activeCategory.value = 'anthropic'
            state.activeGroupId.value = groupId
            state.priceMode.value = priceMode
            return state
          },
        }
        const html = await renderToString(createSSRApp(component))
        const rows = [...html.matchAll(/<tr\b[^>]*>[\s\S]*?<\/tr>/g)]
          .map(([row]) => row)
          .filter((row) => row.includes('<strong>claude-haiku-5-5</strong>'))

        assert.equal(rows.length, 1, `${groupId}/${priceMode} should show a single model row`)
        const [row] = rows
        assert.equal([...row.matchAll(/aria-label="复制 claude-haiku-5-5"/g)].length, 1)
        assert.match(row, /按单次请求的输入 tokens 数分档；输入、输出和缓存读取均按对应档计费/)
        const labels = [...row.matchAll(/<span class="context-tier-label">([^<]+)<\/span>/g)].map((match) => match[1])
        assert.deepEqual(labels, Array(4).fill(['输入 ≤ 10 万 tokens', '输入 &gt; 10 万 tokens']).flat())

        const priceClass = priceMode === 'group' ? 'group-price' : 'official-price'
        const amounts = [...row.matchAll(new RegExp(`<strong class="${priceClass}">([^<]+)<`, 'g'))]
          .map((match) => match[1])
        assert.deepEqual(amounts, priceMode === 'group' ? expectedPrices : expectedOfficialPrices)

        if (priceMode === 'official') {
          const dollars = [...row.matchAll(/<span class="official-usd">([^<]+)<\/span>/g)]
            .map((match) => match[1].trim())
          assert.deepEqual(dollars, ['$0.1', '$0.5', '$0.5', '$2.5', '$0.01', '$0.05', '$0.60', '$3.00'])
        }
      }
    }
  } finally {
    await server.close()
  }
})
