# Codex 接入

Codex 是 OpenAI 的编程助手，适合阅读代码、修改文件、解释报错、生成脚本和整理项目。它能看到本机文件，也能配合终端和编辑器处理真实项目任务。

按照本文安装 Codex，再按快速开始导入配置后，ChatGPT 桌面应用中的 Codex 或 Codex CLI 会使用本中转站的 API Key 发起模型请求。

需要使用 ChatGPT 桌面应用中 Codex 的内置生图时，看 [Codex 内置生图](/images/codex-image-direct)。需要保留 ChatGPT 登录或手机连接时，看 [保留 ChatGPT 登录](/chatgpt-login-usegoodai)。

## 安装 Codex

### Windows

#### 安装 ChatGPT 桌面应用

新手只安装 ChatGPT 桌面应用，然后在应用里选择 Codex 就可以使用，不需要安装 Codex CLI、Node.js 或 npm。已经安装旧版独立 Codex 应用的用户，按平时方式更新，更新后会变成新的 ChatGPT 桌面应用。

打开 OpenAI 官方 ChatGPT 桌面应用下载页：

```text
https://chatgpt.com/download/
```

选择 Windows，并在 Microsoft Store 完成安装。

不想打开 Microsoft Store 界面时，可以在 PowerShell 运行：

```powershell
winget install Codex -s msstore
```

安装完成后，从 Windows 开始菜单打开 ChatGPT，登录 ChatGPT 账号或使用 API Key。在左上角切换到 **ChatGPT Codex** 后新建任务。

#### 只在需要终端时安装 CLI

只有要在 PowerShell、CMD 或脚本里运行 `codex` 命令时，才安装 Codex CLI。只用 ChatGPT 桌面应用中 Codex 的用户跳过这一段。

```powershell
winget install OpenJS.NodeJS.LTS
npm install -g @openai/codex
codex --version
```

看到版本号，说明 CLI 安装成功。

### macOS

打开终端，执行：

```bash
npm install -g @openai/codex
codex --version
```

### Linux / WSL

打开 Linux 或 WSL 终端，执行：

```bash
sudo apt update
sudo apt install -y nodejs npm
npm install -g @openai/codex
codex --version
```

在 WSL 里运行 `codex` 时，配置放进 WSL 的 `~/.codex`，不是 Windows 用户目录。

## 把 Codex 接入 UseGoodAI

安装完成后，按 [快速开始](/quick-start) 在后台创建 API Key，再点击 **导入到 CCS**。CC Switch 会把 UseGoodAI 地址、API Key 和模型写入 Codex，不需要手动修改文件。

后台无法打开 CC Switch，或需要直接管理本机配置文件时，进入 [Codex 手动接入](/clients/codex-manual-config)。

## 关于 `/v1`

Codex 这类后台已经生成专用配置的场景，优先使用后台复制出来的地址，不要自己额外加 `/v1`。

只有普通 OpenAI-compatible 客户端手动填写 `Base URL` 时，才填写：

```text
https://api.usegoodai.com/v1
```

简单判断：有后台生成配置就复制后台配置；没有生成配置、只能手动填 OpenAI-compatible 地址时，再考虑 `/v1`。

## 启动并验证

CLI 用户重新打开终端，运行：

```bash
codex
```

ChatGPT 桌面应用用户完全退出应用后重新打开，切换到 Codex 后新建一个任务。

进入 Codex 后，发送一句测试：

```text
测试
```

然后回到后台 **使用记录** 页面，确认这个 API Key 有调用记录。

## 接入常见问题

| 现象 | 处理方式 |
| --- | --- |
| `codex` 命令不存在 | 重新打开终端；确认 `npm install -g @openai/codex` 执行成功。 |
| 后台没有调用记录 | 检查 `config.toml` 和 `auth.json` 是否放在当前运行环境的 `.codex` 目录，文件名不要带 `.txt` 后缀。 |
| Windows 配了但 WSL 不生效 | WSL 读取的是 WSL 里的 `~/.codex`，不是 Windows 的 `%USERPROFILE%\.codex`。 |
| 401 / Unauthorized | 重新复制 `auth.json`，检查 API Key 是否完整、前后有没有多余空格。 |
| 403 / model not found | 检查 API Key 所属分组是否支持 `config.toml` 里的模型。 |

更多复杂报错看 [报错与踩坑](/errors/)。
