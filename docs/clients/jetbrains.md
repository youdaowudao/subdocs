# JetBrains 接入 UseGoodAI

JetBrains 系 IDE 包括 IntelliJ IDEA、PyCharm、WebStorm、GoLand、PhpStorm 等。本文适合在支持自定义 OpenAI 服务商的 JetBrains 插件里接入 UseGoodAI，让 IDE 插件使用 UseGoodAI 的 API Key、Base URL 和模型名发起请求。

本文只修改 JetBrains 插件里的 provider / API 设置，不修改 Codex 配置，也不配置 JetBrains 官方 AI 账号。

## 安装插件

在 JetBrains IDE 中打开插件市场，安装支持自定义 OpenAI 服务商的 AI 插件。

配置入口常见名称：

| 入口 | 用途 |
| --- | --- |
| OpenAI-compatible | 填写 Base URL、API Key 和模型名 |
| OpenAI API | 支持自定义 API 地址时按本文填写 |
| Custom provider / 自定义服务商 | 手动添加 UseGoodAI |

插件只显示固定官方账号、不能填写自定义 API 地址时，不属于本文场景。

## 填写 UseGoodAI

在插件的 provider 或 API 设置里新增一条配置：

| 字段 | 填写 |
| --- | --- |
| Name / Provider name | `UseGoodAI` |
| Provider type / API 类型 | `OpenAI-compatible`、`OpenAI API` 或 `Custom` |
| Base URL / API Base / Endpoint | `https://api.usegoodai.com/v1` |
| API Key / Token | UseGoodAI API Key |
| Model | 当前 Key 分组可用模型，例如 `gpt-5.5` |

Base URL 只填到 `/v1`，不要追加其它路径。

## 添加模型

模型列表能自动出现时，选择当前 Key 分组可用模型。

模型列表为空时，手动添加一个模型名：

```text
gpt-5.5
```

模型名要和当前 Key 分组里的模型完全一致。

## 测试

在 JetBrains 插件里选择 `UseGoodAI` provider 和刚填写的模型，发送：

```text
请用一句话回复：JetBrains 已连接 UseGoodAI 成功。
```

能正常回复，说明当前插件已经切到 UseGoodAI。

## 排查

| 现象 | 处理 |
| --- | --- |
| `401 Unauthorized` | 重新复制 API Key，确认填在当前插件正在使用的 provider |
| `403 Forbidden` / `block` | 换成当前 Key 分组支持的模型；仍失败时看 [报错与踩坑](/errors/) |
| 模型列表为空 | 手动添加模型 ID 后直接测试聊天 |
| 路径错误 / Not Found | Base URL 改回 `https://api.usegoodai.com/v1` |
| 连接超时 | 检查 JetBrains HTTP Proxy、系统代理、防火墙和证书拦截 |
| 浏览器可用但 IDE 不可用 | 检查 IDE 代理和插件是否启用了 `UseGoodAI` provider |

JetBrains IDE 有自己的 HTTP Proxy 设置。代理、证书或本地网关改写请求时，优先在 IDE 设置和插件设置里排查。
