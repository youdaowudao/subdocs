# Trae 接入 UseGoodAI

Trae 是 AI IDE。本文在 Trae 的自定义 provider / API 配置里添加 `UseGoodAI`，让当前聊天、编辑器或 Agent 功能使用 UseGoodAI 的 API Key、Base URL 和模型名发起请求。

本文不修改 Trae 官方模型市场，也不配置官方账号登录。

## 添加 provider

在 Trae 设置里找到模型、AI Provider、API Provider 或类似入口，新增一个自定义服务商。

| 字段 | 填写 |
| --- | --- |
| Name / Provider Name | `UseGoodAI` |
| Type / API Type | `OpenAI`、`OpenAI-compatible` 或 `Custom OpenAI` |
| Base URL | `https://api.usegoodai.com/v1` |
| API Key | UseGoodAI API Key |
| Model | 当前 Key 分组可用模型，例如 `gpt-5.5` |

Base URL 只填到 `/v1`，不要追加其它路径。

Trae 同时有官方模型市场和自定义 API 配置时，进入自定义 API 配置页，不要只在官方模型市场里切模型。

## 添加模型

模型列表能自动出现时，选择当前 Key 分组可用模型。

模型列表为空时，手动添加一个模型名：

```text
gpt-5.5
```

模型名要和当前 Key 分组里的模型完全一致。

## 测试

保存 provider 后，在 Trae 当前使用的聊天、编辑器补全或 Agent 功能里选择 `UseGoodAI` provider 和模型。

发送：

```text
请用一句话回复：Trae 已通过 UseGoodAI 连接成功。
```

能正常回复，说明当前 Trae 功能已经切到自定义 provider。

## 排查

| 现象 | 处理 |
| --- | --- |
| 仍然走官方模型 | 回到当前聊天、编辑器或 Agent 的模型选择器，重新选择 `UseGoodAI` |
| `401 Unauthorized` | 重新复制 API Key，保存后重新选择 provider，必要时重启 Trae |
| `403 Forbidden` / `block` | 确认 Key 分组支持当前模型；仍失败时看 [外接调用 User-Agent 说明](/external/user-agent) |
| 模型不可用 / model not found | 换成当前 Key 分组里的完整模型名 |
| 模型列表为空 | 手动添加模型名后直接发送消息测试 |
| 路径错误 | Base URL 改回 `https://api.usegoodai.com/v1` |
| 网络代理 / 证书问题 | 检查系统代理、公司网络、证书信任和代理插件 |

Trae 的工具调用、上下文、代码编辑、联网、文件操作等能力，以当前 Trae 自定义 provider 支持情况为准。先确认聊天能走通，再测试 Agent 能力。
