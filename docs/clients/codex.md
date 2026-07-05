# Codex

Codex 是 OpenAI 的编程助手，适合阅读代码、修改文件、解释报错、生成脚本和整理项目。它能看到本机文件，也能配合终端和编辑器处理真实项目任务。

按照本文配置完成后，Codex App 或 Codex CLI 会使用本中转站的 API Key 发起模型请求。本文修改本机 `config.toml` 和 `auth.json`。

需要保留 Codex App 的 ChatGPT 登录、内置生图或手机连接时，看 [保持 ChatGPT 登录同时连接中转站](/chatgpt-login-usegoodai)。

## 安装 Codex

### Windows

#### 安装 Codex App

新手只安装 Codex App 就可以使用，不需要安装 Codex CLI、Node.js 或 npm。

打开 OpenAI 官方 Codex App 页面：

```text
https://developers.openai.com/codex/app
```

点击 **Download for Windows**，会跳转到 Microsoft Store 安装 Codex。

也可以直接打开 Microsoft Store，搜索：

```text
Codex
```

选择 OpenAI 发布的 **Codex**，点击 **获取 / 安装**。

不想打开 Microsoft Store 界面时，可以在 PowerShell 运行：

```powershell
winget install Codex -s msstore
```

安装完成后，从 Windows 开始菜单打开 Codex，登录 ChatGPT 账号或使用 API Key。

#### 只在需要终端时安装 CLI

只有要在 PowerShell、CMD 或脚本里运行 `codex` 命令时，才安装 Codex CLI。只用 Codex App 的用户跳过这一段。

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

## 配置 Codex

先按 [快速开始](/quick-start) 在后台创建 API Key，并复制后台给出的 Codex 配置内容。这里复制的是两段文本，不是两个可下载文件：

| 文件 | 作用 |
| --- | --- |
| `config.toml` | 写模型、接口地址和 provider 配置 |
| `auth.json` | 写 API Key |

在本机找到或新建这两个文件，再把后台对应内容分别粘进去：

| 你在哪里运行 Codex | 文件位置 |
| --- | --- |
| Windows App / PowerShell / CMD | `C:\Users\你的用户名\.codex\config.toml` 和 `C:\Users\你的用户名\.codex\auth.json`；也可以在地址栏输入 `%USERPROFILE%\.codex` |
| macOS / Linux / WSL | `~/.codex/config.toml` 和 `~/.codex/auth.json` |

Windows 文件名必须正好是 `config.toml` 和 `auth.json`，不要保存成 `config.toml.txt` 或 `auth.json.txt`。

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

Codex App 用户完全退出 App 后重新打开，新建一个任务。

进入 Codex 后，发送一句测试：

```text
用一句话回复：UseGoodAI Codex 连接是否成功。
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
