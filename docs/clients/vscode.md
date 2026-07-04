# VS Code

VS Code 适合已经在编辑器里写代码的用户。这里重点讲 **OpenAI Codex 扩展** 怎么配合 UseGoodAI 使用。

核心结论：Codex VS Code 扩展和 Codex CLI 共享同一套 Codex 配置。也就是说，UseGoodAI 的模型端点、模型名、API Key 仍然按 [Codex 接入文档](/clients/codex) 配好；VS Code 这里只负责安装扩展、打开项目、使用 Codex 面板。

## 先分清三条路线

| 你要做什么 | 该怎么走 |
| --- | --- |
| 在 VS Code 里直接用 Codex 改项目 | 安装 OpenAI Codex 扩展，沿用 Codex 配置 |
| 配置 UseGoodAI API | 去 [Codex](/clients/codex) 配 `config.toml` 和 `auth.json` |
| 在 VS Code Chat 里接自己的模型 | 走 VS Code BYOK，和 Codex 扩展不是同一个入口 |

不要把 VS Code BYOK、GitHub Copilot、Codex 扩展混成一件事。想让 Codex 扩展请求走 UseGoodAI，重点是 Codex 配置本身正确，不是在 VS Code 里另写一套模型端点。

## 使用 Codex 扩展

### 1. 先完成 Codex 配置

先按 [Codex 接入文档](/clients/codex) 完成 UseGoodAI 配置。配置完成后，你应该已经有：

| 文件 | 作用 |
| --- | --- |
| `config.toml` | 写模型、provider、base_url 等 Codex 配置 |
| `auth.json` | 写 API Key |

Codex 扩展会读取这套配置。不要在 VS Code 设置里重复填写 `base_url`、`model_provider` 或 API Key。

### 2. 安装 OpenAI Codex 扩展

在 VS Code 扩展市场搜索：

```text
OpenAI Codex
```

安装后，侧边栏会出现 Codex 面板。如果没有看到，可以在命令面板搜索 `Codex`，或重新加载 VS Code 窗口。

### 3. 打开项目根目录

在 VS Code 里选择：

```text
File -> Open Folder
```

打开项目根目录，不要只打开单个文件。Codex 需要看到完整项目结构、Git 状态和相关文档，才方便修改代码。

### 4. 在 Codex 面板里使用

打开 Codex 面板后，直接输入任务，例如：

```text
检查这个项目的启动方式，并告诉我如何本地运行。
```

如果 Codex 配置已经接入 UseGoodAI，请求会按 Codex 配置走。修改配置后建议重启 VS Code，避免扩展仍然使用旧配置。

## 配置在哪里改

Codex 扩展的模型配置不在 VS Code Chat 的 BYOK 里改，而是在 Codex 配置里改。

| 要改什么 | 去哪里改 |
| --- | --- |
| Codex 使用哪个 provider | `~/.codex/config.toml` |
| Codex 使用哪个模型 | `~/.codex/config.toml` |
| UseGoodAI API Key | `~/.codex/auth.json` |
| MCP、sandbox、approval 等 Codex 行为 | `~/.codex/config.toml` |
| VS Code Chat 自己的模型 | VS Code BYOK / Language Models |

在 Codex 扩展里，也可以从设置齿轮进入 Codex Settings，打开 `config.toml` 检查当前配置。

## BYOK 单独说明

VS Code BYOK 是给 **VS Code Chat / Language Models** 用的，不等于 Codex 扩展配置。

| 场景 | 是否走 Codex 配置 |
| --- | --- |
| Codex 扩展改项目 | 是 |
| Codex CLI | 是 |
| VS Code Chat 选择 BYOK 模型 | 否 |
| GitHub Copilot 补全 | 否 |

如果只是想让 VS Code Chat 里出现自己的模型，可以在命令面板搜索：

```text
Chat: Manage Language Models
```

然后按 VS Code 的表单填写 API Key、模型名和接口地址。这个配置不会自动变成 Codex 扩展配置。

## 常见问题

| 问题 | 处理方式 |
| --- | --- |
| Codex 扩展没有走 UseGoodAI | 回到 [Codex](/clients/codex) 检查 `config.toml` 和 `auth.json` 是否放在当前环境的 `.codex` 目录。 |
| 配置改了但扩展没变化 | 重启 VS Code，或在 Codex 扩展里重新打开任务。 |
| VS Code Chat 能用，但 UseGoodAI 后台没记录 | 你可能用的是 VS Code / Copilot / BYOK 通道，不是 Codex 扩展。 |
| Codex 面板找不到 | 确认已安装 OpenAI Codex 扩展，并重新加载 VS Code 窗口。 |
| BYOK 模型不能用于 Codex | 正常。BYOK 是 VS Code Chat 的模型入口，不等于 Codex provider。 |
| 想确认扩展读的是哪份配置 | 在 Codex 面板齿轮里打开 Codex Settings，再打开 `config.toml`。 |

## 相关链接

- [Codex](/clients/codex)
- [Codex 进阶用法](/external/codex-advanced)
- [常见错误](/errors/)
- [OpenAI Codex IDE extension](https://developers.openai.com/codex/ide)
- [OpenAI Codex config basics](https://developers.openai.com/codex/config-basic)
