# VS Code

VS Code 适合已经习惯在编辑器里写代码的用户。它可以打开项目、查看改动、运行终端，也可以通过 Copilot / Codex 相关能力把 AI 放进编辑器工作流里。

::: tip 先分清两条路线
如果你想让 **Codex CLI 使用 UseGoodAI**，先按 [Codex](/clients/codex) 完成配置。VS Code 只是编辑器，不需要在这里重复写 `config.toml` 和 `auth.json`。

如果你想用 **VS Code Chat / BYOK 模型**，那走的是 VS Code 的语言模型配置，和 Codex CLI 配置不是同一个入口。
:::

## 先看你要做什么

| 你的目标 | 建议看 |
| --- | --- |
| 在 VS Code 里打开项目，然后用 Codex CLI 工作 | [配合 Codex CLI 使用](#配合-codex-cli-使用) |
| 使用 VS Code 里的 OpenAI Codex agent | [OpenAI Codex 扩展](#openai-codex-扩展) |
| 在 VS Code Chat 里接自己的模型 Key | [BYOK 和自定义端点](#byok-和自定义端点) |
| 后台没有记录、模型看不到、命令不存在 | [常见问题](#常见问题) |

## 准备事项

| 需要 | 用来做什么 |
| --- | --- |
| VS Code | 打开项目、查看改动、使用内置终端 |
| Git | 让 Codex 和 VS Code 正确识别代码仓库 |
| Codex CLI | 用 UseGoodAI 跑本地 Codex 任务 |
| UseGoodAI API Key | 写入 Codex 配置或 VS Code BYOK 配置 |
| 可用模型分组 | 避免模型不可用或 403 |

VS Code 下载地址：

```text
https://code.visualstudio.com/
```

## 配合 Codex CLI 使用

这是最稳的用法：VS Code 负责编辑器体验，Codex CLI 负责读取 UseGoodAI 配置并执行任务。

### 1. 先完成 Codex 配置

先按 [Codex 接入文档](/clients/codex) 完成：

- 安装 Codex CLI。
- 创建 `.codex` 配置目录。
- 放好 `config.toml` 和 `auth.json`。
- 运行一次 `codex --version` 和基础测试。

这里不要重新手写配置，也不要自己补接口路径。后台生成什么，就按 Codex 文档使用什么。

### 2. 用 VS Code 打开项目

在项目目录里打开终端，运行：

```bash
code .
```

也可以在 VS Code 里选择：

```text
File -> Open Folder
```

打开的是项目根目录，不要只打开某一个文件。Codex 需要看到完整项目结构，才能正确理解代码、文档和 Git 状态。

### 3. 使用 VS Code 内置终端运行 Codex

在 VS Code 里打开终端：

```text
Terminal -> New Terminal
```

常用命令：

```bash
codex
```

如果你只想让 Codex 处理当前项目，建议在项目根目录运行。这样它读取到的上下文更干净，也更容易定位文件。

## OpenAI Codex 扩展

VS Code 官方文档已经把 OpenAI Codex 列为第三方 agent。它可以在 VS Code 的 Chat / Agents 体验里启动 Codex 会话。

需要注意：这个入口通常走 GitHub Copilot 的认证和计费，不等同于 UseGoodAI 的 Codex CLI 配置。

| 项目 | 说明 |
| --- | --- |
| 本地 Codex 会话 | 需要安装 OpenAI Codex 扩展 |
| Cloud Codex 会话 | 从 VS Code 的 Cloud / Partner Agent 入口选择 |
| 认证方式 | 官方文档说明为通过 Copilot 订阅认证 |
| UseGoodAI 配置 | 主要适用于 Codex CLI 路线 |

如果目标是使用 UseGoodAI API Key，优先走 [Codex CLI](/clients/codex) 路线；如果目标是体验 VS Code 官方集成，则按 VS Code 的 OpenAI Codex 扩展和 Copilot 入口操作。

## BYOK 和自定义端点

VS Code 的 BYOK 是把自己的模型 Key 接入 VS Code Chat 体验。它适合在 VS Code 里直接聊天、改代码、选择模型。

### 当前状态

| 能力 | 状态 |
| --- | --- |
| 普通 BYOK 模型 | VS Code 已提供语言模型管理入口 |
| 自定义 OpenAI-compatible 端点 | VS Code 1.122 起 Custom Endpoint provider 已进入 Stable |
| Chat、tools、MCP | 可使用 BYOK 模型 |
| Inline suggestions / NES | 仍需要 GitHub 登录和对应 Copilot 能力 |
| Agents Window 里使用 BYOK 模型 | 需要 Local agent provider；官方 release note 标注该入口仍在 Insiders |
| Codex CLI 配置复用 | 不等同于 VS Code BYOK，需要分别配置 |

也就是说，正式版 VS Code 已经可以通过 Custom Endpoint 添加兼容 Chat Completions / Responses / Messages 的模型端点。  
但如果你想在 Agents Window 里用 BYOK 模型，要留意 VS Code 当前版本和 Local agent provider 状态；这个入口可能仍需要 Insiders。

BYOK 主要解决的是 VS Code Chat、工具调用和 MCP 这类交互。它不是把所有 Copilot 功能都替换成自己的 API Key；代码补全、下一步编辑建议、语义搜索等能力，仍可能需要 GitHub 登录、Copilot 订阅或组织策略放行。

### 入口位置

在 VS Code 里打开命令面板：

```text
Ctrl/Cmd + Shift + P
```

搜索：

```text
Chat: Manage Language Models
```

也可以在 Chat 输入框的模型选择器里点击齿轮，进入模型管理界面。

### 填写原则

| 项目 | 怎么填 |
| --- | --- |
| API Key | 填 UseGoodAI 后台创建的 Key |
| 模型名 | 填后台可用模型，例如 `gpt-5.5`、`gpt-5.4-mini` |
| API 类型 | 优先选择 Responses；不支持时再看 Chat Completions 兼容模式 |
| Base URL / URL | 按 VS Code 当前表单要求填写；如果表单要求完整模型端点，就按它的 `chatLanguageModels.json` 结构填写 |

::: warning 不要混用两套配置
Codex CLI 读取的是 Codex Home 里的配置；VS Code BYOK 读取的是 VS Code 的语言模型配置。一个地方配好了，不代表另一个地方自动生效。
:::

## 建议用法

### 普通开发

1. 用 VS Code 打开项目。
2. 在内置终端运行 `codex`。
3. 让 Codex 修改文件。
4. 在 VS Code 里查看 diff、运行测试、手动确认。

这种方式最适合接入 UseGoodAI，因为请求由 Codex CLI 发出，后台记录也更容易对应。

### 编辑器内聊天

如果你想直接在 VS Code Chat 里问代码、改局部文件，可以使用 VS Code 的语言模型和 BYOK 能力。这个路线更依赖 VS Code / Copilot 当前版本，不同账号、版本和组织策略可能看到的入口不同。

### 多项目处理

如果你同时处理多个项目，不建议把所有项目塞进同一个窗口。更清楚的做法是：

- 一个 VS Code 窗口打开一个项目。
- 每个项目在自己的终端里运行 Codex。
- 重要任务先确认 Git 状态，再让 Codex 修改。

## 常见问题

### VS Code 里能聊天，但 UseGoodAI 后台没有记录

大概率是你走的是 VS Code / Copilot 自己的模型通道，不是 UseGoodAI 的 Codex CLI 配置。

处理方式：

1. 在 VS Code 内置终端运行 `codex`。
2. 确认 Codex CLI 已按 [Codex 文档](/clients/codex) 配置。
3. 再去 UseGoodAI 后台查看请求记录。

### 找不到 Custom Endpoint

先确认 VS Code 版本。Custom Endpoint provider 在 VS Code 1.122 起进入 Stable；如果版本较旧，可能仍看不到入口。

处理方式：

- 先升级 VS Code。
- 如果你使用的是旧版本，再检查是否需要 VS Code Insiders。
- 检查 Copilot / BYOK 相关策略是否被组织禁用。
- 如果只是为了用 UseGoodAI 跑 Codex，改走 [Codex CLI](/clients/codex)。

### 模型出现在列表里，但不能用于 Agent

有些模型只能聊天，不能作为 agent 模型使用。VS Code 通常要求 agent 模型支持工具调用。

处理方式：

- 换支持工具调用的模型。
- 检查模型配置里的能力字段。
- 使用 `gpt-5.5` 或 `gpt-5.4` 这类更适合复杂代码任务的模型。

### BYOK 可以聊天，但没有代码补全

这是正常边界。VS Code 官方说明里，BYOK 主要用于 Chat、tools 和 MCP；inline suggestions、下一步编辑建议和部分嵌入相关能力仍可能需要 GitHub 登录或 Copilot 支持。

如果你的目标是代码补全，检查 GitHub/Copilot 登录和订阅状态；如果你的目标是让 Codex 用 UseGoodAI 改项目，直接使用 [Codex CLI](/clients/codex) 更清楚。

### VS Code 终端里 `codex` 命令不存在

说明 VS Code 启动时没有读到 Codex CLI 所在路径，或者 Codex CLI 还没装好。

处理方式：

1. 关闭并重新打开 VS Code。
2. 在系统终端里运行 `codex --version`。
3. 如果系统终端也不行，回到 [Codex 安装步骤](/clients/codex) 重新检查。
4. 如果系统终端可以、VS Code 终端不行，检查 VS Code 使用的 Shell 是否和你安装 Codex 的环境一致。

## 相关链接

- [Codex](/clients/codex)
- [Codex 进阶用法](/external/codex-advanced)
- [常见错误](/errors/)
