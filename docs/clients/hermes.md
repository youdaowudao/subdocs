# Hermes Agent 接入

Hermes Agent 是偏终端和 Agent 工作流的工具，适合让模型参与项目协作、文件操作、工具调用和长上下文任务。接入 UseGoodAI 时，不要把所有场景都理解成“OpenAI 兼容模式”：先看 Hermes 当前入口和 UseGoodAI 后台给出的协议，再决定 `api_mode`。

::: tip 核心结论
| 项目 | 填写原则 |
| --- | --- |
| Provider | 本页按 `Custom endpoint` 配置 UseGoodAI |
| API mode | 后台和 Hermes 都明确支持 Responses 时优先选 Responses；否则普通自定义端点按 Chat Completions |
| Base URL | Responses 按后台或生成配置填写；普通 OpenAI-compatible 手动配置时填 `https://api.usegoodai.com/v1` |
| API Key | 从 UseGoodAI 后台创建并复制 |
| Model | 以 UseGoodAI 后台当前分组可用模型为准，例如 `gpt-5.5` |
:::

## 适合谁

| 你的情况 | 是否适合 |
| --- | --- |
| 想在终端里使用 Agent 处理代码、文件和工具调用 | 适合 |
| 想把 UseGoodAI 接到 Hermes 的自定义模型端点 | 适合 |
| Windows 用户愿意使用 WSL2 | 适合 |
| 只想要网页聊天窗口 | 不适合，优先看 Cherry Studio / Open WebUI |

## 配置前先确认

| 项目 | 要确认什么 |
| --- | --- |
| API Key | Key 已创建，且没有复制漏字符 |
| 分组 | Key 所属分组支持你要用的模型 |
| 模型名 | 使用后台显示的完整模型 ID，不要凭印象改写 |
| 协议 | 后台是否明确给出 Responses；Hermes 当前向导是否能选择对应 `api_mode` |
| 请求记录 | 配完后要回 UseGoodAI 后台确认是否有调用记录 |

::: warning 模型名不是协议
`gpt-5.5` 这类模型名不能单独决定走 Responses 还是 Chat Completions。协议要看 UseGoodAI 后台入口、Hermes 当前版本和你选择的 `api_mode`。
:::

## 安装 Hermes

Hermes 官方快速开始推荐 Linux、macOS 或 Windows WSL2。Windows 用户如果遇到路径、依赖或终端工具问题，优先换到 WSL2 里配置。

### Linux / macOS / WSL2

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

安装后重新加载 shell：

```bash
source ~/.bashrc
```

如果你使用 zsh：

```bash
source ~/.zshrc
```

检查 Hermes 是否可用：

```bash
hermes --version
hermes doctor
```

| 结果 | 说明 |
| --- | --- |
| 能看到版本号，`doctor` 没有关键错误 | 可以继续配置 provider |
| 命令不存在 | 重新打开终端，或检查安装脚本是否把 Hermes 加入 PATH |
| Windows 原生命令行报依赖问题 | 改用 WSL2 终端重装 |

## 配置 UseGoodAI

### 1. 创建 API Key

进入 UseGoodAI 后台 **API 密钥** 页面，创建一个给 Hermes 使用的 Key。

创建后先确认：

| 项目 | 正确状态 |
| --- | --- |
| Key | 已复制完整 |
| 分组 | 支持你准备在 Hermes 里填写的模型 |
| 模型 | 后台能看到该模型，例如 `gpt-5.5` |

### 2. 打开 Hermes 模型向导

在终端运行：

```bash
hermes model
```

Provider 选择：

| 向导里看到什么 | 怎么选 |
| --- | --- |
| `Custom endpoint` / `self-hosted` / `VLLM` 类选项 | 选择它，用来接 UseGoodAI 自定义端点 |
| 名称相似但来源不明的配置模板 | 不要仅凭名称套用；先确认它的 Base URL、协议和 Key 读取方式 |
| 没有 Custom endpoint | 先升级 Hermes，再重新运行 `hermes model` |

### 3. 选择协议 / API mode

Hermes 官方文档把协议抽象成 `api_mode`。选择时按这张表判断：

| UseGoodAI 后台和 Hermes 当前版本 | Hermes 里选择 | 说明 |
| --- | --- | --- |
| 后台明确给出 Responses，Hermes 向导也能选 Responses / Codex Responses | Responses / `codex_responses` | 优先使用，不要降级成普通兼容模式 |
| Hermes 当前 Custom endpoint 只能按普通 OpenAI-compatible 端点配置 | Chat Completions / `chat_completions` | 这时才按普通兼容方式填写 |
| 不确定协议，向导提供 Auto-detect | 可先用 Auto-detect | 配完必须看后台调用记录；失败后重新运行 `hermes model` 显式选择 |
| 向导完全不问 `api_mode` | 先升级 Hermes | 官方资料显示新版 Custom Endpoint 向导会保存 `api_mode` |

::: warning 不要自己拼接口路径
Responses 和 Chat Completions 的请求体、输出结构不同。除非 Hermes 或 UseGoodAI 后台明确要求填写完整接口地址，否则只填对应入口要求的 Base URL，不要手动补具体接口路径。
:::

### 4. 填写 UseGoodAI 参数

按向导提示填写：

| Hermes 提示 | 填写 |
| --- | --- |
| API Base URL / Base URL | Responses 按后台或生成配置填写；普通 OpenAI-compatible 手动配置时填 `https://api.usegoodai.com/v1` |
| API Key | UseGoodAI 后台复制的 Key |
| Model name | 后台分组里实际可用的模型，例如 `gpt-5.5` |
| Context window | 不确定先留空或用默认值；如果必须填写，以后台模型信息为准 |
| API mode | 按上一节选择，不要让模型名替你决定协议 |

如果你选择的是普通 OpenAI-compatible 手动配置，Base URL 只填：

```text
https://api.usegoodai.com/v1
```

不要再追加具体接口路径，Hermes 会按所选 `api_mode` 组织请求。

### 5. 启动 Hermes

配置完成后运行：

```bash
hermes
```

如果你的版本提示使用 chat 子命令，也可以运行：

```bash
hermes chat
```

## 验证是否接通

进入 Hermes 后发送一个低成本测试：

```text
用一句话回复：Hermes 已经通过 UseGoodAI 连接成功。
```

然后回到 UseGoodAI 后台查看调用记录。

| 现象 | 判断 |
| --- | --- |
| Hermes 正常回复，后台有调用记录 | 接入成功 |
| Hermes 报错，后台没有记录 | 请求没有打到 UseGoodAI，先查 Base URL 和 Hermes 实际读取的配置 |
| 后台有记录，但模型报错 | 模型名或 Key 分组不匹配 |
| 401 | API Key 错误、过期，或 Hermes 没读到这个 Key |
| 403 / `block` | 分组、协议或外接识别规则不匹配；再看 `User-Agent` 是否需要处理 |

## 查看或备份配置

新手优先用 `hermes model` 跑通，不建议一开始手写 YAML。需要排查时再查看配置：

```bash
hermes config
hermes config edit
```

普通 OpenAI-compatible 手动配置的典型形态如下：

```yaml
model:
  provider: custom
  default: gpt-5.5
  base_url: https://api.usegoodai.com/v1
  api_key: sk-...
  api_mode: chat_completions
```

| 字段 | 说明 |
| --- | --- |
| `provider` | 自定义端点使用 `custom` |
| `default` | 模型名必须和 UseGoodAI 后台一致 |
| `base_url` | 这里只适用于普通 OpenAI-compatible 手动配置 |
| `api_key` | 也可以按 Hermes 当前版本的密钥管理方式保存 |
| `api_mode` | 普通兼容端点用 `chat_completions`；Responses 入口不要照抄本示例 |

## 常见错误

| 错误 | 常见原因 | 处理方式 |
| --- | --- | --- |
| 后台没有任何调用记录 | Hermes 没有请求到 UseGoodAI | 运行 `hermes config`，确认当前 provider、Base URL 和 Key |
| `401 Unauthorized` | Key 错误、过期或没被读取 | 重新复制 UseGoodAI Key，重新跑 `hermes model` |
| `403 block` / `403 Forbidden` | 分组、协议或外接识别不匹配 | 先确认 Key 分组和 `api_mode`；如果仍失败，再按后台要求检查 `User-Agent` |
| 模型不存在 | 模型名不属于当前 Key 分组 | 回后台复制完整模型 ID，注意大小写、点号、横线和斜杠 |
| 选择 Responses 后 Hermes 无法解析回复 | 当前端点或 Hermes 版本不匹配 | 确认后台是否明确支持 Responses；必要时升级 Hermes 或改用后台允许的协议 |
| 普通兼容配置报路径错误 | Base URL 填成了完整接口路径 | 普通 OpenAI-compatible 手动配置只填本页给出的 Base URL |
| Hermes 仍使用旧 provider | 旧配置、环境变量或会话状态覆盖 | 退出 Hermes，重新运行 `hermes model`，必要时用 `hermes config edit` 清理旧项 |
| Windows 下命令、路径、依赖异常 | 原生命令行环境不稳定 | 使用 WSL2 重新安装和配置 |

### `User-Agent` 怎么处理

默认先不要改。只有遇到 `403 block`、后台提示外接识别异常，或你的代理支持自定义 Header 时，再处理 `User-Agent`。

| 场景 | 做法 |
| --- | --- |
| Hermes 直连后能正常回复 | 保持默认 |
| 经过代理或网关 | 检查最终发到 UseGoodAI 的请求头，不只看本地客户端 |
| 后台要求补外接标识 | 使用稳定、可识别的 Hermes / CLI 标识，不要伪装成不相关客户端 |

## 排查顺序

1. 运行 `hermes doctor`，先排除 Hermes 本地安装问题。
2. 运行 `hermes config`，确认当前 provider、模型、Base URL 和 `api_mode`。
3. 回 UseGoodAI 后台看是否有调用记录。
4. 没有记录时，优先排 Base URL、Key 读取和旧配置覆盖。
5. 有记录但失败时，再排模型名、分组、协议和 `User-Agent`。

## 参考资料

- [UseGoodAI 外接兼容与 Base URL 说明](../external/base-url)
- [UseGoodAI User-Agent 说明](../external/user-agent)
- Hermes Quickstart：<https://hermes-ai.net/docs/quickstart>
- Hermes Configuration：<https://hermes-agent.nousresearch.com/docs/user-guide/configuration>
- Hermes AI Providers：<https://hermes-agent.nousresearch.com/docs/integrations/providers>
- Hermes Adding Providers：<https://hermes-agent.nousresearch.com/docs/developer-guide/adding-providers>
