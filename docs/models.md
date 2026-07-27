---
title: 模型价格
aside: false
outline: false
---

<script setup>
import ModelPricing from './.vitepress/theme/components/ModelPricing.vue'
</script>

<ModelPricing />

## 如何切换模型

已经接入中转站后，在客户端添加或选择不同的模型名即可。Base URL 和 API Key 不变，只改模型名。

价格表第一列就是模型 ID，旁边按钮可以复制。实际能用哪些模型，以当前 API Key 所属分组为准。

**我的 API Key 支持哪些模型？**

登录 UseGoodAI 管理后台 **API 密钥**，找到正在使用的 Key，查看它所属的分组。分组里列出的模型，才是这个 Key 可以使用的模型。

**切换模型需要重新配置吗？**

不需要。普通 OpenAI-compatible 客户端保留 `https://api.usegoodai.com/v1` 和当前 API Key，只把 `Model` 改成新模型名。

**提示 `model not found` 或 `403`？**

当前 API Key 所属分组不支持这个模型。回管理后台检查分组，或换成该分组支持的模型。

完整填写方式看 [客户端接入](/clients/#模型怎么填)。
