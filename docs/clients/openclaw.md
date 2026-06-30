# OpenClaw 接入 UseGoodAI

OpenClaw 是个人 AI Agent 网关，可以通过浏览器 Control UI、Telegram、Discord、飞书等渠道使用模型。接入 UseGoodAI 的关键，是在 OpenClaw 里新增一个指向 UseGoodAI 的 model provider，然后把默认模型切到这个 provider。

::: tip 本页推荐的新手路径
先用 OpenClaw 官方 onboarding 把 Gateway 跑起来，再手动添加一个 `usegoodai` provider。第一次接入建议先走普通 OpenAI-compatible 配置，跑通后再按当前客户端入口切换其它 API adapter。
:::

## 需要准备

| 项目 | 说明 |
| --- | --- |
| Node.js | OpenClaw 官方建议 Node 24，Node 22.19+ 也支持 |
| UseGoodAI API Key | 从 UseGoodAI 后台创建并复制 |
| 可用模型名 | 以 UseGoodAI 后台当前分组显示为准，例如 `gpt-5.5` |
| OpenClaw 配置文件 | 通常是 `~/.openclaw/openclaw.json` |

::: warning 不要猜模型名
`gpt-5.5` 只是示例。你的 Key 能不能调用某个模型，取决于 UseGoodAI 后台分组和权限。后台没有显示的模型，不要照抄到 OpenClaw 里。
:::

## 1. 安装 OpenClaw

如果你还没有安装 OpenClaw，先按官方推荐方式安装。

macOS / Linux：

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

Windows PowerShell：

```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
```

如果你已经自己管理 Node，也可以用 npm：

```bash
npm install -g openclaw@latest
```

安装后检查版本：

```bash
openclaw --version
```

## 2. 完成初次启动

运行 OpenClaw onboarding：

```bash
openclaw onboard --install-daemon
```

第一次使用可以按这个顺序选：

| 步骤 | 建议 |
| --- | --- |
| QuickStart / Advanced | 选 QuickStart 或默认路径 |
| Model/Auth | 如果你准备手动配置 UseGoodAI，可以先跳过或选一个临时 provider，只要让配置文件生成出来 |
| Channel | 新手可以先跳过，后面用浏览器 Control UI 验证 |
| Skills | 只安装你信任的技能；不确定可以先少装 |
| Daemon | 推荐允许安装，这样 Gateway 会作为后台服务运行 |

完成后检查 Gateway：

```bash
openclaw gateway status
openclaw dashboard
```

`openclaw dashboard` 会打开本机 Control UI。能打开页面，说明 OpenClaw 本身已经跑起来。

## 3. 创建 UseGoodAI API Key

进入 UseGoodAI 后台的 **API 密钥** 页面，创建一个给 OpenClaw 使用的 Key。

创建后确认两件事：

| 检查项 | 为什么重要 |
| --- | --- |
| Key 所属分组 | 决定能调用哪些模型 |
| 模型 ID | 需要逐字填进 OpenClaw 的 `models` 里 |

## 4. 添加 UseGoodAI provider

打开 OpenClaw 配置文件：

```text
~/.openclaw/openclaw.json
```

把下面这段合并进去。不要覆盖你已有的 channel、gateway、agent 等配置。

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "usegoodai/gpt-5.5"
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "usegoodai": {
        "baseUrl": "https://api.usegoodai.com/v1",
        "apiKey": "sk-把这里换成你的UseGoodAI API Key",
        "api": "openai-completions",
        "models": [
          {
            "id": "gpt-5.5",
            "name": "gpt-5.5",
            "reasoning": true,
            "input": ["text"],
            "contextWindow": 200000,
            "maxTokens": 8192,
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            }
          }
        ]
      }
    }
  }
}
```

需要改的字段只有这些：

| 字段 | 必须怎么改 |
| --- | --- |
| `apiKey` | 换成 UseGoodAI 后台复制的 Key |
| `agents.defaults.model.primary` | `usegoodai/` 后面的模型名换成你的可用模型 |
| `models.providers.usegoodai.models[0].id` | 换成同一个模型名 |
| `models.providers.usegoodai.models[0].name` | 建议和 `id` 保持一致 |

这些字段通常保持示例值即可：

| 字段 | 说明 |
| --- | --- |
| `baseUrl` | 普通 OpenAI-compatible 手动配置填 `https://api.usegoodai.com/v1` |
| `api` | 普通兼容路径使用 `openai-completions` |
| `models.mode` | `merge` 表示合并自定义 provider，不替换 OpenClaw 内置 catalog |
| `cost` | 只影响 OpenClaw 本地成本显示；UseGoodAI 实际计费以后台为准 |

::: warning Base URL 不要拼完整接口
这里的 `baseUrl` 只填到 `/v1`。不要写成 `https://api.usegoodai.com/v1/chat/completions`，也不要写成 `https://api.usegoodai.com/v1/responses`。具体请求路径由 OpenClaw 的 `api` adapter 自己拼。
:::

## 5. 用环境变量保存 Key

如果你不想把 Key 明文写进配置文件，可以把 `apiKey` 改成环境变量引用：

```json
{
  "apiKey": "${USEGOODAI_API_KEY}"
}
```

然后在启动 OpenClaw 的环境里设置变量。

macOS / Linux：

```bash
export USEGOODAI_API_KEY="sk-从后台复制的APIKey"
```

Windows PowerShell：

```powershell
$env:USEGOODAI_API_KEY="sk-从后台复制的APIKey"
```

如果 OpenClaw 已经安装成后台服务，设置环境变量后可能需要重启 Gateway，确保服务进程能读到新变量。

## 6. 重启并验证

保存配置后重启 OpenClaw：

```bash
openclaw gateway restart
openclaw models status
openclaw models list --provider usegoodai
```

然后打开 Control UI：

```bash
openclaw dashboard
```

发送一条很小的测试消息：

```text
用一句话回复：OpenClaw 已经通过 UseGoodAI 连接成功。
```

再回到 UseGoodAI 后台查看这个 Key 是否出现调用记录或用量变化。

| 现象 | 说明 |
| --- | --- |
| OpenClaw 正常回复，后台有记录 | 接入成功 |
| OpenClaw 报错，后台没有记录 | 配置没有生效、Base URL 不对，或 Gateway 没读到新配置 |
| 后台有记录但报模型错误 | 模型名或 Key 分组权限不匹配 |
| `models list --provider usegoodai` 看不到模型 | `models.providers.usegoodai.models` 没合并成功，或配置文件 JSON 有问题 |

## API adapter 怎么选

OpenClaw 当前模型配置里支持多个 adapter，包括 `openai-completions` 和 `openai-responses`。不要把它们和内置 OpenAI/Codex OAuth 路径混在一起。

| 场景 | `api` 建议 | Base URL |
| --- | --- | --- |
| 普通 OpenAI-compatible 自定义 provider | `openai-completions` | `https://api.usegoodai.com/v1` |
| 明确要用 Responses，且当前 UseGoodAI 入口和 OpenClaw 版本都按 Responses 配置 | `openai-responses` | 按当前入口要求填写；不要手动拼 `/responses` |
| OpenClaw 内置 OpenAI / Codex OAuth | 不按本页手动 provider 示例配置 | 按 OpenClaw 官方 OpenAI/Codex onboarding |

如果你不确定自己当前入口是哪一种，先用 `openai-completions` 跑通。需要切到 Responses 时，只改同一个 provider 的 `api`，不要同时改 Base URL、模型路径和 provider 名。

## Headers / User-Agent

多数情况下不需要手动加 headers。OpenClaw 会把 `apiKey` 作为认证信息交给 provider adapter 处理。

只有在 UseGoodAI 后台提示需要识别外接来源、或者你遇到 `403 block` / `403 Forbidden` 且已经确认 Key、模型、Base URL 都正确时，再加 headers：

```json
{
  "headers": {
    "Authorization": "Bearer sk-把这里换成你的UseGoodAI API Key",
    "User-Agent": "OpenClaw/0.1 external-cli"
  }
}
```

需要改的字段：

| 字段 | 说明 |
| --- | --- |
| `Authorization` | 如果手动写，必须和你的 UseGoodAI API Key 一致 |
| `User-Agent` | 可保留示例，也可以按后台要求填写稳定、可识别的客户端标识 |

::: warning 不要随便伪装成其它客户端
普通 OpenClaw provider 不要直接复用 Codex、Claude CLI 或浏览器的 User-Agent。只有 UseGoodAI 后台或排查结果明确要求时，再按要求改。
:::

## 常见问题

### Base URL 要不要加 `/chat/completions`？

不要。本页普通兼容路径只填：

```text
https://api.usegoodai.com/v1
```

`/chat/completions` 是 OpenClaw 在 `openai-completions` adapter 下实际请求的路径，不是用户手动填写的 Base URL。

### 能不能填 `/responses`？

普通 `openai-completions` 配置不能填 `/responses`。如果你确认当前要用 `openai-responses`，也不要把 `/responses` 拼进 Base URL；只按当前客户端入口选择 adapter，路径由 adapter 处理。

### 401 / Unauthorized

优先检查 API Key：

| 检查项 | 处理 |
| --- | --- |
| Key 是否完整 | 重新从 UseGoodAI 后台复制 |
| Key 是否填到 `usegoodai` provider | 不要填到其它 provider |
| 环境变量是否生效 | 重新打开终端或重启 Gateway |
| 手动 headers 是否和 `apiKey` 冲突 | 先删掉 headers，只保留 `apiKey` 验证 |

### 403 / Forbidden

先确认模型名和分组权限。只有 Key、模型、Base URL 都确认无误后，再检查是否需要补 `User-Agent`。

### 模型不可用

把 `gpt-5.5` 换成 UseGoodAI 后台当前分组显示的模型 ID。注意大小写、点号、横线、斜杠都要一致。

### 后台没有调用记录

这通常说明请求没有打到 UseGoodAI。按顺序检查：

| 顺序 | 检查 |
| --- | --- |
| 1 | `openclaw gateway restart` 后是否仍在用旧配置 |
| 2 | `openclaw models list --provider usegoodai` 是否能看到模型 |
| 3 | `baseUrl` 是否只写到 `https://api.usegoodai.com/v1` |
| 4 | 当前会话是否真的选择了 `usegoodai/模型名` |

## 参考资料

- OpenClaw 官方 Getting started：<https://docs.openclaw.ai/start/getting-started>
- OpenClaw 官方 Onboarding：<https://docs.openclaw.ai/start/wizard>
- OpenClaw 官方 Models：<https://docs.openclaw.ai/concepts/models>
- OpenClaw 官方 Model providers：<https://docs.openclaw.ai/concepts/model-providers>
- [UseGoodAI 外接兼容与 Base URL 说明](../external/base-url)
- [UseGoodAI User-Agent 说明](../external/user-agent)
