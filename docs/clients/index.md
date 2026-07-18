# 客户端接入

这里整理 UseGoodAI 可以接入的常见客户端。  
第一次使用先看 [快速开始](/quick-start)，跑通一次后，再按自己的工具选择对应页面。

## 按使用场景选择

| 你要做什么 | 进入 |
| --- | --- |
| 用 Codex CLI / ChatGPT 桌面应用中的 Codex 写代码 | [Codex 接入](/clients/codex) |
| CC Switch 无法一键导入，需要手动修改 Codex 配置文件 | [Codex 手动接入](/clients/codex-manual-config) |
| 在 VS Code 里配合 Codex 或 BYOK 使用 | [VS Code 接入](/clients/vscode) |
| 在 Claude Desktop APP 或 Claude Code CLI 中使用 GPT-5.6 | [Claude Code / Desktop 接入](/clients/claude-code-desktop) |
| 在 CC Switch 中手动添加 Claude Code 供应商 | [CC Switch 手动接入](/clients/cc-switch) |
| 在 JetBrains IDE 里接入 | [JetBrains](/clients/jetbrains) |
| 在 Trae 里接入 | [Trae](/clients/trae) |
| 使用无限画布做图片创作 | [无限画布](/images/infinite-canvas) |
| 用图形界面聊天、管理多个模型 | [Cherry Studio](/clients/cherry-studio) |
| 自建一个网页聊天面板 | [Open WebUI](/clients/open-webui) |
| 把 UseGoodAI 接到 OpenClaw 龙虾 Gateway | [OpenClaw](/clients/openclaw) |
| 把 UseGoodAI 接到 Hermes 记忆 / Skill Agent | [Hermes](/clients/hermes) |
| 自建团队聊天面板 | [LibreChat](/clients/librechat) |

## 通用 API 地址

普通客户端手动填写 `Base URL` 时，使用：

```text
https://api.usegoodai.com/v1
```

后台或 CC Switch 已经生成配置时，直接复制生成结果，不要自己额外补 `/v1`。

## Codex 相关页面怎么选

| 页面 | 用途 |
| --- | --- |
| [Codex 接入](/clients/codex) | 第一次安装、配置和排查基础问题 |
| [Codex 手动接入](/clients/codex-manual-config) | CC Switch 无法一键导入时，手动写入 `config.toml` 和 `auth.json` |
| [Codex 内置生图](/images/codex-image-direct) | 在 ChatGPT 桌面应用中的 Codex 调用内置生图工具 |
| [保留 ChatGPT 登录](/chatgpt-login-usegoodai) | ChatGPT 桌面应用中的 Codex 保留 ChatGPT 登录和手机连接 |
| [VS Code](/clients/vscode) | 想在编辑器里配合 Codex，或了解 VS Code BYOK |
| [Codex 进阶](/external/codex-advanced) | 已经跑通后，学习 profile、会话、权限、手机连接和多 Codex 工作流 |
| [Codex 周边工具](/external/codex-tools) | 想了解 Git、ripgrep、GitHub CLI、MCPHub、Superpowers 等辅助工具 |
