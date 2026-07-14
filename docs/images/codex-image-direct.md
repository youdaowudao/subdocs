# Codex 内置生图

Codex 内置生图是 ChatGPT 桌面应用中 Codex 自带的 `image_gen` 工具，不是图片生成 API、无限画布，也不是让 Codex 写脚本调接口。本文适合已经按 [快速开始](/quick-start) 把 Codex 接到 UseGoodAI 的用户；改完后，Codex 继续走中转站，并且可以在 Codex 里直接调用内置生图工具。

本文只改本机 `config.toml`。`auth.json` 继续使用快速开始里写入的 UseGoodAI API Key，不要删除，也不要把 Key 写进下面的配置。

## 复制完整配置

先找到本机 `config.toml`：

| 运行环境 | 文件位置 |
| --- | --- |
| Windows 桌面应用 / PowerShell / CMD | `C:\Users\你的用户名\.codex\config.toml` |
| macOS / Linux / WSL | `~/.codex/config.toml` |

打开 `config.toml`，先复制一份旧内容做备份，再全选删除旧内容，把下面这一整段粘贴进去并保存：

```toml
model_provider = "UseGoodAI"
model = "gpt-5.5"
review_model = "gpt-5.5"
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.UseGoodAI]
name = "UseGoodAI"
base_url = "https://api.usegoodai.com"
wire_api = "responses"
requires_openai_auth = false
http_headers = { "x-openai-actor-authorization" = "local-image-extension" }

[features]
image_generation = true
```

后台快速开始给你的模型不是 `gpt-5.5` 时，只改 `model` 和 `review_model` 两行，填当前 API Key 所属分组可用的模型名。

## 重启 Codex

保存 `config.toml` 后，完全退出 ChatGPT 桌面应用，再重新打开。

Windows 用户要从右下角托盘退出 ChatGPT。只点窗口右上角关闭按钮时，应用可能还在后台运行，不会读取刚保存的配置。

重新打开后，切换到 Codex，新开一个对话或任务。不要继续旧对话。

## 测试内置生图

在新的 Codex 对话里发送：

```text
请用内置生图工具生一张图：白底上的红色苹果。
```

能生成图片，就说明 Codex 已经拿到内置生图工具，并且请求走 UseGoodAI 中转站。

---

::: tip 到这里就够了
已经生成图片的用户，不需要继续看下面。下面内容只给需要保留旧配置、排查问题或理解字段含义的用户。
:::

## 进阶：保留旧配置

已经配置过 MCP、插件、项目权限或其它自定义项时，不要全选覆盖。保留旧配置，只改下面几处。

在 `[model_providers.UseGoodAI]` 里确认有这两行：

```toml
requires_openai_auth = false
http_headers = { "x-openai-actor-authorization" = "local-image-extension" }
```

在已有的 `[features]` 里加入：

```toml
image_generation = true
```

`config.toml` 全文只能有一个 `[features]`。原来已经有 `[features]` 时，把 `image_generation = true` 放进去，不要再新建第二个 `[features]`。

## 进阶：配置项含义

`requires_openai_auth = false` 表示这个自定义 provider 不使用 OpenAI 官方账号鉴权。UseGoodAI 用户的鉴权仍然来自快速开始里写入的 `auth.json` 和中转站配置，不是关闭 UseGoodAI 的 API Key 检查。

设为 `true` 时，Codex 会把这个 provider 当成 OpenAI 鉴权入口处理，适合仍然要走 OpenAI 账号或 OpenAI API Key 的代理场景。UseGoodAI 中转站按本文配置走，保持 `false`。

`http_headers = { "x-openai-actor-authorization" = "local-image-extension" }` 用来让 Codex 的内置生图扩展按本地生图入口发起请求。

`image_generation = true` 是 Codex 的内置生图开关。没有这一行，Codex 可能能聊天、能改代码，但当前会话拿不到内置 `image_gen` 工具。

## 常见问题

| 现象 | 处理方式 |
| --- | --- |
| Codex 能聊天，但不能生图 | 检查 `[features]` 里是否有 `image_generation = true` |
| 提示当前会话没有 `image_gen` 工具 | 完全退出 ChatGPT 桌面应用，重新打开 Codex 后新开任务 |
| 配置后 Codex 打不开 | 检查 `config.toml` 里是不是写了两个 `[features]`，有两个就合并成一个 |
| 请求没有到 UseGoodAI | 检查 `base_url` 是否是后台 Codex 配置使用的中转站地址，`auth.json` 是否还在 `.codex` 目录里 |
| 401 / Unauthorized | 重新按 [快速开始](/quick-start) 复制 `auth.json`，确认 API Key 没有少字符 |
