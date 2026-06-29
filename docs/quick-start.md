# 快速开始：Codex 接入 UseGoodAI

本页只做一件事：创建一个可用的 API Key，然后让 **Codex CLI** 通过 UseGoodAI 跑起来。

接入信息固定如下：

| 项目 | 填写内容 |
| --- | --- |
| API 地址 | `https://api.usegoodai.com/v1` |
| 推荐模型 | `gpt-5.5` |
| 接入方式 | Responses API |
| 配置文件 | `config.toml` + `auth.json` |

## 第一步：创建 API Key

进入后台的 **API Key / 令牌 / 密钥** 页面，点击 **创建**。

创建时按下面填写：

| 项目 | 填写方式 |
| --- | --- |
| 名称 | `Codex CLI` |
| 分组 | 选择支持 `gpt-5.5` 的 Codex / OpenAI 分组 |
| 额度 | 按后台默认值或你的套餐额度填写 |
| 过期时间 | 不需要临时限制就保持默认 |

保存后，复制生成的 API Key。它通常以 `sk-` 开头：

```text
sk-你的API_KEY
```

后面写 `auth.json` 时会用到这个 Key。

## 第二步：安装 Codex CLI

Codex CLI 需要 Node.js 和 npm。先在终端检查：

```bash
node -v
npm -v
```

如果这两条命令没有版本号，先安装 Node.js LTS。Windows 用户建议使用 PowerShell 或 Windows Terminal。

安装 Codex CLI：

```bash
npm install -g @openai/codex
```

确认安装成功：

```bash
codex --version
```

## 第三步：创建 Codex 配置目录

Codex 会读取用户目录下的 `.codex` 文件夹。

::: code-group

```powershell [Windows PowerShell]
New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex"
notepad "$env:USERPROFILE\.codex\config.toml"
```

```bash [macOS / Linux]
mkdir -p ~/.codex
nano ~/.codex/config.toml
```

:::

## 第四步：写入 config.toml

把下面内容完整复制到 `config.toml`：

```toml
model_provider = "usegoodai"
model = "gpt-5.5"
model_reasoning_effort = "high"
disable_response_storage = true
model_context_window = 1000000
model_auto_compact_token_limit = 900000

[model_providers.usegoodai]
name = "UseGoodAI"
base_url = "https://api.usegoodai.com/v1"
wire_api = "responses"
requires_openai_auth = true
```

保存文件。

这里已经使用 Codex 推荐的 Responses 接入方式，不需要再额外选择其它协议。

## 第五步：写入 auth.json

继续创建认证文件：

::: code-group

```powershell [Windows PowerShell]
notepad "$env:USERPROFILE\.codex\auth.json"
```

```bash [macOS / Linux]
nano ~/.codex/auth.json
```

:::

把下面内容复制进去，并把 `sk-你的API_KEY` 换成第一步创建的 Key：

```json
{
  "OPENAI_API_KEY": "sk-你的API_KEY"
}
```

保存文件。

## 第六步：启动 Codex

重新打开一个终端，然后执行：

```bash
codex
```

进入 Codex 后，可以先发一句测试：

```text
用一句话回复：UseGoodAI Codex 已连接。
```

能正常收到回复，就说明 Codex 已经通过 UseGoodAI 接入成功。

## 第七步：确认后台记录

回到后台的 **日志 / 调用记录 / 用量记录** 页面，确认能看到刚才的请求。

重点看三项：

| 项目 | 正常情况 |
| --- | --- |
| 接口 | `/v1/responses` |
| 模型 | `gpt-5.5` |
| API Key | 显示你刚才创建的 `Codex CLI` Key |

能看到记录，说明请求已经打到 UseGoodAI；看不到记录，通常是本地配置文件没有生效或 API 地址写错。

## 常见问题

| 现象 | 先检查这里 |
| --- | --- |
| `codex` 命令不存在 | Codex CLI 是否安装成功，终端是否重新打开 |
| 401 / Unauthorized | `auth.json` 里的 API Key 是否复制完整 |
| 403 / Forbidden | API Key 选择的分组是否支持 `gpt-5.5` |
| 连接失败 / 404 | `base_url` 是否是 `https://api.usegoodai.com/v1`，不要漏掉 `/v1` |
| 后台没有调用记录 | `config.toml` 和 `auth.json` 是否放在正确的 `.codex` 目录 |
| Windows 配置不生效 | 文件名不要变成 `config.toml.txt` 或 `auth.json.txt` |

## 下一步

- 需要看 Codex 参数含义：进入 [Codex CLI 接入](/clients/codex)
- 需要确认模型和分组：进入 [模型与分组](/models/groups)
- 遇到 403：进入 [403 常见错误](/errors/403)
