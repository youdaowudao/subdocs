# 客户端接入

这里整理 UseGoodAI 可以接入的常见客户端。  
如果你是第一次使用，建议先看 [快速开始](/quick-start)，已经跑通过一次后，再按自己的工具选择对应页面。

## 按使用场景选择

| 你要做什么 | 建议看 |
| --- | --- |
| 用 Codex CLI / Codex App 写代码 | [Codex](/clients/codex) |
| 在 VS Code 里配合 Codex 或 BYOK 使用 | [VS Code](/clients/vscode) |
| 在 Claude Code Desktop 里接第三方 GPT | [Claude Code Desktop](/clients/claude-code-desktop) |
| 统一管理多个 Agent / CLI 配置 | [CC Switch](/clients/cc-switch) |
| 在 JetBrains IDE 里接入 | [JetBrains](/clients/jetbrains) |
| 在 Trae 里接入 | [Trae](/clients/trae) |
| 使用无限画布做图片创作 | [无限画布](/images/infinite-canvas) |
| 用图形界面聊天、管理多个模型 | [Cherry Studio](/clients/cherry-studio) |
| 自建一个网页聊天面板 | [Open WebUI](/clients/open-webui) |
| 使用 OpenClaw Agent / Gateway | [OpenClaw](/clients/openclaw) |
| 使用 Hermes Agent | [Hermes](/clients/hermes) |
| 自建团队聊天面板 | [LibreChat](/clients/librechat) |

## 接入前先准备

- 一个 UseGoodAI API Key。
- 一个可用分组。
- 一个实际存在的模型名。
- 客户端里能填写自定义 `Base URL`、`API Key` 和 `Model`。

普通 OpenAI-compatible 客户端手动配置时，常用 API 地址是：

```text
https://api.usegoodai.com/v1
```

::: tip
如果后台或 CC Switch 已经生成了配置，优先复制生成结果，不要自己额外补 `/v1`。只有客户端要求你手动填写 OpenAI-compatible `Base URL` 时，再按对应教程填写。
:::

## Codex 相关页面怎么选

| 页面 | 适合谁 |
| --- | --- |
| [Codex](/clients/codex) | 第一次安装、配置 UseGoodAI、排查基础问题 |
| [VS Code](/clients/vscode) | 想在编辑器里配合 Codex，或了解 VS Code BYOK |
| [Codex 进阶用法](/external/codex-advanced) | 已经跑通后，学习 profile、会话、权限、多 Codex 工作流 |
| [Codex 周边工具](/external/codex-tools) | 想了解 Git、ripgrep、GitHub CLI、MCPHub、Superpowers 等辅助工具 |
