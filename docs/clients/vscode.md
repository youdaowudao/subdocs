# 在 VS Code 里使用 UseGoodAI

VS Code 是常用的代码编辑器，适合需要打开项目文件、看代码结构、查看修改记录的用户。相比 Codex App，VS Code 的优势是项目上下文更直观：文件树、代码、终端、Git 改动都在同一个窗口里，适合边看边改、边运行边验证。

这页只讲 VS Code 里的两条接入方式：**OpenAI Codex 扩展** 和 **VS Code BYOK**。

## 两条路线

| 目标 | 入口 | 配置位置 |
| --- | --- | --- |
| 用 Codex 扩展读项目、改代码、跑任务 | OpenAI Codex 扩展 | Codex 的 `.codex` 配置 |
| 让 VS Code Chat / Copilot 使用第三方模型 | VS Code BYOK | VS Code 的 Language Models 配置 |

这两条路线互不影响。Codex 扩展不会读取 VS Code BYOK；VS Code Chat 也不会自动读取 Codex 的 `.codex` 配置。

## Codex 扩展

先把本中转站的模型配置填进 Codex，让 Codex 请求走中转站。已经按 [Codex 接入文档](/clients/codex) 配好的人，可以直接在 VS Code 扩展市场安装：

```text
OpenAI Codex
```

安装后打开项目根目录，在 Codex 面板里直接使用。项目根目录要包含代码、文档和 Git 信息，不要只打开单个文件。

## BYOK

BYOK 是 **Bring Your Own Key**。它的作用是把你自己的模型 API Key 接进 VS Code 的 Chat / Agent 体验。

VS Code Chat 使用本中转站模型，走 BYOK。它和 Codex 扩展没有配置联动。

打开命令面板：

```text
Chat: Manage Language Models
```

选择：

```text
Add Models -> Custom Endpoint
```

UseGoodAI 这种兼容接口，优先按 Custom Endpoint 配。表单里先填：

| 项目 | 填什么 |
| --- | --- |
| Group name | `UseGoodAI` |
| API Key | UseGoodAI 后台创建的 API Key |
| API type | 优先选 `Responses`；旧聊天兼容接口选 `Chat Completions` |

VS Code 打开 `chatLanguageModels.json` 后，关键字段按下面写：

```json
[
  {
    "name": "UseGoodAI",
    "vendor": "customendpoint",
    "apiKey": "这里完整填写你的中转站key",
    "apiType": "responses",
    "models": [
      {
        "id": "gpt-5.5",
        "name": "gpt-5.5",
        "url": "https://api.usegoodai.com/v1/responses",
        "toolCalling": true,
        "vision": true,
        "maxInputTokens": 128000,
        "maxOutputTokens": 64000
      }
    ]
  }
]
```

选择 `chat-completions` 时，把 `apiType` 和 `url` 改成：

```json
"apiType": "chat-completions",
"url": "https://api.usegoodai.com/v1/chat/completions"
```

配置后，在 VS Code Chat 的模型选择器里选中刚添加的模型。只有选中了这个 BYOK 模型，VS Code Chat 的请求才会走对应的第三方 API。

BYOK 主要覆盖 VS Code 的 Chat 体验、工具调用和 utility tasks。代码补全、semantic search、依赖 embeddings 的能力，仍可能需要 GitHub 登录、Copilot 支持或组织策略放行。

## 验证

| 要验证什么 | 怎么测 |
| --- | --- |
| Codex 扩展是否走 UseGoodAI | 在 Codex 面板发起一个代码任务，然后看 UseGoodAI 后台是否有请求 |
| VS Code Chat 是否走 UseGoodAI | 在 Chat 模型选择器选中 `UseGoodAI / gpt-5.5` 后发消息，再看 UseGoodAI 后台 |
