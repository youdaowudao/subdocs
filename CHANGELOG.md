# 文档版本记录

## 0.1.1（2026-11-10）

- 影响范围：文档站「模型价格」页的「CC MAX 满血版本」和「CC MAX 外接分组」，两组倍率均为 1.5。
- 相对上一版：新增 `claude-fable-5-2`，排在 `claude-fable-5-1` 前；保留原有模型及顺序。Fable 5.1 的说明移除「最新」。
- 官方标准价格：输入 $8、输出 $40、缓存读取 $0.20／百万 tokens，来源为 [Anthropic 官方模型文档](https://platform.claude.com/docs/en/models/fable-5-2/overview)。
- 按现有分组规则计算：输入 ¥12、输出 ¥60、缓存读取 ¥0.30／百万 tokens；一百万输入加一百万输出合计 ¥72。
- 测试结果：`node --test tests/model-pricing.test.mjs tests/model-pricing-render.test.mjs` 共 61 项全部通过，覆盖两组排序、复制模型 ID、官方价和分组价显示，以及其它分组不包含新模型；`npm run docs:build` 通过。
- 验证范围：已完成本地测试和构建，线上结果未验证。
