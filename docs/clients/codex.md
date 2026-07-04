# 在 Codex 里使用 UseGoodAI

Codex 是 OpenAI 的编程助手，适合阅读代码、修改文件、解释报错、生成脚本和整理项目。相比普通聊天工具，Codex 更适合处理真实项目任务：它能看到本机文件，也能配合终端和编辑器工作。

按照本文配置完成后，Codex App 或 Codex CLI 会使用本中转站的 API Key 发起模型请求。你只需要安装 Codex，并把本机 `config.toml` 和 `auth.json` 改成后台给出的正确内容。

## 安装 Codex

### Windows

不熟悉命令行，直接安装 Codex App。需要在终端里使用 Codex CLI，打开 PowerShell，依次执行：

```powershell
winget install OpenJS.NodeJS.LTS
npm install -g @openai/codex
codex --version
```

看到版本号，就说明 CLI 安装成功。

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

WSL 用户只记住一点：在 WSL 里运行 `codex`，配置就放进 WSL 的 `~/.codex`，不是 Windows 用户目录。

## 把 Codex 对接到 UseGoodAI API

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

然后回到后台，看这个 API Key 是否出现调用记录或用量变化。

## 接入常见问题

| 现象 | 处理方式 |
| --- | --- |
| `codex` 命令不存在 | 重新打开终端；确认 `npm install -g @openai/codex` 执行成功。 |
| 后台没有调用记录 | 检查 `config.toml` 和 `auth.json` 是否放在当前运行环境的 `.codex` 目录，文件名不要带 `.txt` 后缀。 |
| Windows 配了但 WSL 不生效 | WSL 读取的是 WSL 里的 `~/.codex`，不是 Windows 的 `%USERPROFILE%\.codex`。 |
| 401 / Unauthorized | 重新复制 `auth.json`，检查 API Key 是否完整、前后有没有多余空格。 |
| 403 / model not found | 检查 API Key 所属分组是否支持 `config.toml` 里的模型。 |

更多复杂报错看 [报错与踩坑](/errors/)。
