# Codex

本页适合第一次安装 Codex，或已经看过 [快速开始](/quick-start) 但没有跑通、需要按系统排查的用户。

::: tip CLI 和 App 基本同一套接入逻辑
Codex CLI 和 Codex App 是不同入口，但接入 UseGoodAI 时核心都是：安装 Codex、让 Codex 读取 `.codex` 配置、用同一个 API Key 发起请求。下面主要按 CLI 写，因为命令、路径和报错更容易排查；App 用户也适用。
:::

## 先看你要做什么

| 你的情况 | 直接看 |
| --- | --- |
| 只想最快接入一次 | [快速开始](/quick-start) |
| Windows 里直接用 PowerShell / CMD | [Windows 原生安装](#windows-原生安装) |
| Windows 里用 Ubuntu / Debian 等 WSL | [Windows WSL 安装](#windows-wsl-安装) |
| macOS | [macOS 安装](#macos-安装) |
| Linux | [Linux 安装](#linux-安装) |
| 已经装好，只想配置 UseGoodAI | [配置 UseGoodAI](#配置-usegoodai) |
| 已经跑通，想学习更高级用法 | [Codex 进阶用法](/external/codex-advanced) |
| 想在 VS Code 里配合使用 | [VS Code](/clients/vscode) |
| 后台没记录、401、403、命令不存在 | [常见错误](#常见错误) |

## 接入原则

| 项目 | 结论 |
| --- | --- |
| 主路径 | Codex 优先走 Responses API |
| 配置来源 | 优先复制 UseGoodAI 后台生成的 Codex 配置 |
| 手动配置 | 只在排障或高级自定义时使用 |
| 接口路径 | 不要手动拼 `/responses` 或 `/chat/completions` |
| `/v1` | 后台生成什么就用什么；普通 OpenAI-compatible 手动 Base URL 才写 `https://api.usegoodai.com/v1` |

OpenAI 官方文档把 Responses 作为新项目推荐路径；Codex 接 UseGoodAI 时也应按 Responses 路径配置。手动配置时使用 `wire_api = "responses"`，不要把 Codex 降级成普通 Chat Completions 兼容模式。

## 准备事项

| 需要 | 用来做什么 |
| --- | --- |
| UseGoodAI 账号 | 创建 API Key、查看分组和用量 |
| API Key | 写入 `auth.json`，供 Codex 调用 |
| 支持目标模型的分组 | 避免 403 或 model not found |
| Git | Codex 处理代码仓库时需要 |
| Node.js / npm | 使用 npm 安装 Codex 时需要 |
| Codex CLI 或 Codex App | 实际发起代码任务 |

如果还没有 API Key，先按 [快速开始](/quick-start) 创建。

## 安装入口怎么选

| 安装方式 | 适合谁 |
| --- | --- |
| 官方安装脚本 | 新手优先，少处理 Node/npm 权限问题 |
| npm | 已经装好 Node.js / npm 的用户 |
| Homebrew | 已经在 macOS 上使用 Homebrew 的用户 |

不管用哪种方式，安装完成后都要重新打开终端，再运行 `codex --version` 检查。

## Windows 原生安装

适合在 Windows Terminal、PowerShell 或 CMD 里直接运行 `codex` 的用户。

### 1. 安装 Git

下载并安装 Git for Windows：

```text
https://git-scm.com/install/windows
```

安装后重新打开 PowerShell，检查：

```powershell
git --version
```

### 2. 安装 Node.js

如果你准备用 npm 安装 Codex，安装 Node.js LTS：

```text
https://nodejs.org/
```

检查：

```powershell
node -v
npm -v
```

如果使用官方安装脚本，通常不需要你先处理 npm。

### 3. 安装 Codex CLI

新手优先用官方安装脚本：

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

如果你已经确认 npm 可用，也可以用：

```powershell
npm install -g @openai/codex
```

检查：

```powershell
codex --version
```

### 4. 确认配置目录

Windows 原生环境读取：

```text
%userprofile%\.codex
```

可以按 `Win + R`，输入上面的路径打开。如果目录不存在，就新建 `.codex` 文件夹。

::: warning 文件后缀
Windows 资源管理器可能把文件保存成 `config.toml.txt` 或 `auth.json.txt`。如果配置不生效，先检查后缀。
:::

## Windows WSL 安装

适合在 Ubuntu、Debian 等 WSL 终端里运行 `codex` 的用户。

### 1. 先分清两套目录

Windows 原生和 WSL 是两套用户环境。

| 你在哪里运行 `codex` | 配置应该放哪里 |
| --- | --- |
| PowerShell / CMD / Windows Terminal 原生 Shell | `%userprofile%\.codex` |
| WSL 里的 Ubuntu / Debian 终端 | `~/.codex` |

在 WSL 里运行 `codex` 时，只配置 Windows 的 `%userprofile%\.codex` 通常不会生效。

### 2. 安装 Git 和 Node.js

Ubuntu / Debian 常用命令：

```bash
sudo apt update
sudo apt install -y git nodejs npm
```

检查：

```bash
git --version
node -v
npm -v
```

如果系统源里的 Node.js 太旧，改用 Node.js 官网或你熟悉的版本管理工具安装 LTS。

### 3. 安装 Codex CLI

新手优先用官方安装脚本：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

如果你使用 npm：

```bash
npm install -g @openai/codex
```

检查：

```bash
codex --version
```

### 4. 创建配置目录

```bash
mkdir -p ~/.codex
```

配置文件应该放在：

```text
~/.codex/config.toml
~/.codex/auth.json
```

::: danger 最常见错误
在 Windows 里配好了 `.codex`，但实际在 WSL 里运行 `codex`。这时要把配置放进 WSL 的 `~/.codex`，不是 Windows 的用户目录。
:::

## macOS 安装

### 1. 安装 Git 和 Node.js

macOS 通常自带 Git 或会在首次运行时提示安装 Command Line Tools。检查：

```bash
git --version
```

如果你准备用 npm 安装 Codex，安装 Node.js LTS：

```text
https://nodejs.org/
```

检查：

```bash
node -v
npm -v
```

### 2. 安装 Codex CLI

新手优先用官方安装脚本：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

如果你已经在用 Homebrew：

```bash
brew install --cask codex
```

如果你使用 npm：

```bash
npm install -g @openai/codex
```

检查：

```bash
codex --version
```

### 3. 确认配置目录

macOS 使用：

```text
~/.codex
```

创建并打开：

```bash
mkdir -p ~/.codex
open ~/.codex
```

## Linux 安装

### 1. 安装 Git 和 Node.js

Ubuntu / Debian 示例：

```bash
sudo apt update
sudo apt install -y git nodejs npm
```

检查：

```bash
git --version
node -v
npm -v
```

如果系统源里的 Node.js 版本太旧，改用 Node.js 官网、NodeSource 或你熟悉的版本管理工具安装 LTS。

### 2. 安装 Codex CLI

新手优先用官方安装脚本：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

如果你使用 npm：

```bash
npm install -g @openai/codex
```

检查：

```bash
codex --version
```

### 3. 确认配置目录

Linux 使用：

```text
~/.codex
```

创建目录：

```bash
mkdir -p ~/.codex
```

如果 `npm install -g` 报权限问题，优先改用官方安装脚本，或重新整理 Node.js / npm 的安装方式。

## 配置 UseGoodAI

安装完成后，优先复制 UseGoodAI 后台生成的 Codex 配置，不要自己猜字段。

### 推荐方式：复制后台生成配置

1. 进入 UseGoodAI 后台的 **API 密钥** 页面。
2. 找到要给 Codex 使用的 API Key。
3. 点击 **使用密钥**。
4. 选择 **Codex CLI**。
5. 按你的系统选择 `Windows` 或 `macOS / Linux`。
6. 复制后台生成的 `config.toml`。
7. 复制后台生成的 `auth.json`。
8. 保存到当前运行环境对应的 `.codex` 目录。

| 文件 | 保存位置 |
| --- | --- |
| `config.toml` | `.codex/config.toml` |
| `auth.json` | `.codex/auth.json` |

::: tip 只看当前运行环境
你在哪里运行 Codex，就把配置放到哪里。Windows 原生、WSL、macOS、Linux 的 `.codex` 目录不是同一个目录。
:::

### 手动配置参考

只有后台生成配置不可用、或你在排查配置问题时，才建议手动写。

`config.toml` 示例：

```toml
model = "gpt-5.5"
model_provider = "usegoodai"
model_reasoning_effort = "medium"
disable_response_storage = true

[model_providers.usegoodai]
name = "UseGoodAI"
base_url = "https://api.usegoodai.com/v1"
wire_api = "responses"
requires_openai_auth = true
```

`auth.json` 示例：

```json
{
  "OPENAI_API_KEY": "sk-你的-UseGoodAI-API-Key"
}
```

这里的重点是：

| 字段 | 应该怎么填 |
| --- | --- |
| `model` | 填后台分组支持的模型名，例如 `gpt-5.5` |
| `base_url` | 手动配置 Codex provider 时使用 `https://api.usegoodai.com/v1` |
| `wire_api` | 使用 `responses` |
| `OPENAI_API_KEY` | 填 UseGoodAI 后台创建的 API Key |

不要把 `base_url` 写成：

```text
https://api.usegoodai.com/v1/responses
https://api.usegoodai.com/v1/chat/completions
```

Codex 会按 Responses 协议自己发请求；你只需要给它正确的 provider base URL。

## 启动并验证

CLI 用户重新打开终端，运行：

```bash
codex
```

App 用户重新打开 Codex App，新建一个对话或任务即可。也可以从命令行尝试：

```bash
codex app
```

进入 Codex 后，发送一句测试：

```text
用一句话回复：UseGoodAI Codex 连接是否成功。
```

然后回到 UseGoodAI 后台，看这个 API Key 是否有调用记录或用量变化。

## 怎么判断问题在哪里

| 现象 | 优先判断 |
| --- | --- |
| `codex` 命令不存在 | Codex 没装好，或终端没重新打开 |
| `git` 命令不存在 | Git 没装好，或安装后终端没刷新 |
| `node` / `npm` 命令不存在 | Node.js 没装好；如果不用 npm 安装 Codex，可先跳过 |
| 进入 Codex 后 401 | `auth.json` 里的 API Key 不对，或没有被 Codex 读取 |
| 进入 Codex 后 403 | API Key 所属分组不支持当前模型，或账号权限/额度不允许 |
| model not found | 模型名写错，或分组里没有这个模型 |
| 后台完全没有记录 | Codex 没读到配置，或配置放错目录 |
| Windows 配了但 WSL 不生效 | 配置放到了 Windows 目录，不在 WSL 的 `~/.codex` |
| CLI 能用、App 不生效 | App 没读取到同一套配置，先彻底退出后重开 |

## 常见错误

### `codex` 命令不存在

先关闭终端重新打开，再运行：

```bash
codex --version
```

如果仍然不存在：

| 环境 | 检查 |
| --- | --- |
| Windows 原生 | 重新打开 Windows Terminal；确认安装脚本或 npm 是否成功 |
| WSL | 在 WSL 里运行 `which codex`，不要在 Windows 目录里找 |
| macOS / Linux | 检查安装目录是否进入 `PATH` |

### Node.js 版本太旧

如果你用 npm 安装，建议使用 Node.js LTS。检查：

```bash
node -v
npm -v
```

版本太旧时，重新安装 LTS 后再执行：

```bash
npm install -g @openai/codex
```

### 后台没有任何调用记录

这通常不是模型问题，而是 Codex 没有打到 UseGoodAI。

优先检查：

| 检查项 | 正确状态 |
| --- | --- |
| `config.toml` | 在当前运行环境的 `.codex` 目录 |
| `auth.json` | 和 `config.toml` 在同一个 `.codex` 目录 |
| Windows / WSL | 没有把两套目录混用 |
| 文件名 | 不是 `config.toml.txt` 或 `auth.json.txt` |
| `base_url` | 不要写到 `/responses` 或 `/chat/completions` |

### 401 Unauthorized

优先重新复制 `auth.json`：

- API Key 不要缺字符。
- API Key 前后不要带空格。
- `auth.json` 必须是合法 JSON。
- 改完后重启 Codex CLI 或 Codex App。

### 403 Forbidden

403 通常说明 Key 被识别了，但当前分组、模型、额度或权限不允许这次调用。

按这个顺序查：

1. 回到后台看这个 Key 属于哪个分组。
2. 确认该分组支持 `config.toml` 里的 `model`。
3. 确认模型名和后台显示完全一致。
4. 检查账号余额、套餐、权限或后台拒绝原因。

### 看起来能聊天，但 Codex 能力不完整

优先确认是不是误用了普通 Chat Completions 兼容模式。Codex 接 UseGoodAI 的主路径应走 Responses；后台记录里通常应能看到 `/v1/responses` 相关请求，而不是普通聊天客户端的 `/v1/chat/completions`。

### `/v1` 到底要不要写

按这张表判断：

| 场景 | 怎么填 |
| --- | --- |
| UseGoodAI 后台生成了 Codex 配置 | 复制后台生成内容，不额外改 |
| 手动写 Codex provider | `base_url = "https://api.usegoodai.com/v1"`，`wire_api = "responses"` |
| 普通 OpenAI-compatible 客户端手动填 Base URL | `https://api.usegoodai.com/v1` |
| 客户端要求完整接口路径 | 按客户端自己的说明，不要套用这里 |

不要为了“更完整”手动补成 `/v1/responses` 或 `/v1/chat/completions`。这两个是最终请求路径，不是常规 Base URL。

## 下一步

- 想按截图重新走一遍：看 [快速开始](/quick-start)。
- 分组或模型不可用：看 [模型与分组](/models)。
- 遇到 401：看 [报错与踩坑](/errors/)。
- 遇到 403：看 [报错与踩坑](/errors/)。
