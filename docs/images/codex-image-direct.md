# Codex 直接生图配置说明

这页解决的是一个具体问题：Codex App 按普通快速开始配置接入 UseGoodAI 后，普通模型请求可以走中转站，但不能直接调用 Codex 内置 `image_gen` 生图工具。

当前 Codex `0.142` 按快速开始方法直连中转站 API 后，普通对话、代码任务、文件修改通常可以正常使用；但让 Codex 直接生成图片时，会看到类似报错：

```text
错误：当前会话没有可用的内置 image_gen 工具，因此无法生成图片
```

这个报错不是 API Key 填错，也不是模型不能回复。它的核心含义是：当前 Codex 会话没有拿到内置 `image_gen` 工具。

这里要分清两层能力：

- UseGoodAI provider 负责模型请求，让 Codex 的普通对话和代码任务走第三方 API。
- Codex App 的内置 `image_gen` 属于 App / ChatGPT 登录态里的工具能力，不会因为填了第三方 `base_url` 自动出现。

所以，Codex 生图要按目标选方案：

| 目标 | 推荐方式 | 说明 |
| --- | --- | --- |
| 快速生成几张图片 | 用 [无限画布](/images/infinite-canvas) | 适合临时出图、调提示词、多轮看效果，不需要折腾 Codex 内置工具。 |
| 用图片生成 API | 看 [图片生成 API](/images/image-generation) | 适合自己写脚本、服务端接口、批量任务或接入已有业务系统。 |
| 让 Codex 在工作流里调用生图 | 接生图 MCP 工具，或写一个小插件 | 把 UseGoodAI 生图接口封成工具，让 Codex 明确调用、保存结果、继续处理文件。 |
| 继续用 Codex App 内置 `image_gen` | 用本文方法 | 先让 Codex App 保持 ChatGPT 登录态，再把模型 provider 指到 UseGoodAI；这样保留插件、内置工具和手机端远程使用能力，同时让后台模型请求走第三方 API。 |

本文只讲第三种：保留 Codex App 登录态，同时让模型请求走 UseGoodAI。

## 适用场景

这个方案适合已经在 Windows 上使用 Codex App，并且希望同时保留下面这些能力的用户：

- Codex App 的 ChatGPT 登录态
- Codex App 内置工具和插件
- 内置生图入口
- 手机端远程使用电脑 Codex 的工作方式
- 后台模型请求走 UseGoodAI，使用更灵活的第三方模型

如果只是写脚本调用生图接口，不需要这样绕一层，直接看 [图片生成 API](/images/image-generation)。

## 配置步骤

这页和普通 [快速开始](/quick-start) 不一样。快速开始主要解决“Codex 模型请求能不能走 UseGoodAI”；本页解决的是“在模型请求走 UseGoodAI 的同时，尽量保留 Codex App 的内置工具能力”。

如果担心自己改错，可以把这一节完整复制给 AI，让它帮你合并到 `config.toml`。合并完成后，你只需要在下面这一行的双引号里填入自己的 UseGoodAI API Key：

```toml
experimental_bearer_token = "sk-你的中转站key"
```

按下面顺序来：

1. 打开 Codex App，正常登录 ChatGPT。
2. 确认 Codex App 已经处于登录状态。
3. 打开 `C:\Users\你的用户名\.codex\config.toml`；没有就新建。
4. 修改前先复制一份旧的 `config.toml` 作为备份；如果配置出错，把备份文件改回 `config.toml` 就可以恢复。
5. 把下面这段配置放到文件开头。
6. 如果文件里已经有旧的 `model_provider`、`[model_providers.OpenAI]`、`[model_providers.xxx]`、`base_url = ...` 等模型端点配置，删掉旧的那几段，只保留本页这段 `[model_providers.UseGoodAI]`。
7. 如果文件下方已有 MCP、插件、项目权限、工作区等配置，不需要动，保留原样。
8. 只把 `experimental_bearer_token` 双引号里的内容改成自己的 UseGoodAI API Key。
9. 保存文件。
10. 完全退出 Codex App；不要只关窗口，必要时从托盘或任务管理器结束进程。
11. 重新打开 Codex App，直接输入“生成一张苹果图片”进行测试。

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
base_url = "https://api.usegoodai.com/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "sk-你的中转站key"
```

## 关键要求

`model_provider` 必须和 `[model_providers.UseGoodAI]` 里的名字一致。这里固定写 `UseGoodAI`，不要写 `OpenAI`，否则容易和 Codex 默认 OpenAI provider、ChatGPT 登录态混在一起。

`base_url` 写到 `/v1`：

```text
https://api.usegoodai.com/v1
```

API Key 直接写在 `experimental_bearer_token`。这个方案不需要 Windows 环境变量，也不需要 PowerShell 命令。

不要删除和模型端点无关的配置。例如已经存在的 MCP server、插件、项目权限、工作区 trust 配置，可以继续留在文件下方。

## 常见问题

| 问题 | 处理方式 |
| --- | --- |
| 修改配置后没有生效 | 保存配置后完全退出 Codex App，再重新打开。 |
| 之前配置过环境变量 | 先删掉，避免它干扰本次测试。 |
| 配置里残留 `[model_providers.OpenAI]` | 删除旧的自定义 OpenAI provider，统一使用 `[model_providers.UseGoodAI]`。 |
| 请求没有到达 UseGoodAI | 检查 `base_url` 是否为 `https://api.usegoodai.com/v1`，API Key 是否复制完整。 |
| provider 不生效 | 确认 `model_provider = "UseGoodAI"` 和 `[model_providers.UseGoodAI]` 完全一致。 |

一句话总结：直连第三方 API 只能解决模型请求；要让 Codex 稳定调用外部生图能力，用 MCP 或插件；如果一定要用 Codex App 内置生图，就先登录 ChatGPT，再按本页配置 UseGoodAI provider。
