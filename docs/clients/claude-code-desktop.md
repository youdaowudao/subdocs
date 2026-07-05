# Claude Code Desktop 接入第三方 GPT

Claude Code Desktop 是桌面端代码 Agent。本文在 Claude Code Desktop 里新增一个 `UseGoodAI` 自定义 provider，让第三方 GPT 模型请求走 `https://api.usegoodai.com/v1`。

这只影响 Claude Code Desktop，不会自动配置终端里的 `claude` 命令，也不会影响 Codex。

## 打开配置入口

安装入口：

```text
https://claude.com/download
```

打开 Claude Code Desktop，进入 **Settings**，找到第三方推理或模型服务入口。常见名称包括：

| 入口名称 | 用途 |
| --- | --- |
| Developer / Configure third-party inference | 第三方推理配置 |
| API Provider / Model Provider | 自定义服务商配置 |
| Models / Custom Provider | 模型配置 |

## 添加 UseGoodAI

在 provider / API 配置页新增一条配置：

| 字段 | 填写 |
| --- | --- |
| Provider name / 名称 | `UseGoodAI` |
| Provider type / 类型 | `OpenAI`、`OpenAI-compatible` 或 `Custom` |
| Base URL | `https://api.usegoodai.com/v1` |
| API Key | UseGoodAI API Key |
| Model | 当前 Key 分组可用模型，例如 `gpt-5.5` |

Base URL 只填到 `/v1`，不要追加其它路径。模型名不要填 Claude 模型名。

## 保存并测试

保存配置后彻底退出 Claude Code Desktop，再重新打开。

在模型或 provider 选择处切到 `UseGoodAI`，选择刚才填写的模型，发送：

```text
请用一句话回复：Claude Code Desktop 已通过 UseGoodAI 连接成功。
```

能正常回复，说明当前桌面端已经切到 `UseGoodAI` provider。

## 排查

| 现象 | 处理 |
| --- | --- |
| 找不到第三方推理入口 | 到 Settings 里启用 Developer Mode，按提示重启后再找 Developer 或 Models 入口 |
| 客户端仍在使用 Claude 模型 | 回模型选择处切换 provider 和模型 |
| `401 Unauthorized` | 重新复制 API Key，确认填在 API Key / Token 字段 |
| `403 Forbidden` | 确认 Key 分组支持当前模型；仍失败时看 [报错与踩坑](/errors/) |
| 模型列表为空 | 手动添加当前 Key 分组可用模型 |
| 配置没有生效 | 确认已经 Save / Apply，并彻底退出重开客户端 |
| 网络连接失败 | 检查代理、防火墙、证书和 Base URL 拼写 |

## 切回默认配置

回到第三方推理或 provider 配置页，停用、删除 `UseGoodAI`，或把模型选择切回默认 provider。切换后重启客户端。
