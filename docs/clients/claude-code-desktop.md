# 在 Claude Desktop 和 Claude Code CLI 中使用 GPT-5.6

Claude Desktop 是带图形界面的 AI 工作应用，包含 Chat、Cowork 和 Code 等入口；Claude Code CLI 是在终端里运行的代码 Agent。两者都适合希望保留 Claude 操作方式、同时通过 UseGoodAI 使用 GPT-5.6 的用户。

本文分别配置 Claude Desktop APP 和 Claude Code CLI。APP 通过内置设置写入本机配置，CLI 不修改配置文件，只在当前终端设置两个环境变量；配置完成后，可以直接在当前会话里切换模型。

## 选择配置入口

| 使用入口 | 配置位置 | 影响范围 |
| --- | --- | --- |
| Claude Desktop APP | APP 的第三方推理设置 | APP 内的 Chat、Cowork 和 Code 等功能 |
| Claude Code CLI | 启动 `claude` 的终端 | 从当前终端启动的 Claude Code CLI |

APP 和 CLI 的配置互不替代。使用哪个入口，就完成对应入口下面的步骤。

## 配置 Claude Desktop APP

### 1. 打开第三方推理设置

从 [Claude 官方下载页](https://claude.com/download) 安装并打开 Claude Desktop。首次打开时先不要登录或创建 Anthropic 账号。

macOS 从系统菜单栏进入，Windows 从登录页左上角的菜单进入：

1. 点击 **Help → Troubleshooting → Enable Developer Mode**。
2. 点击 **Developer → Configure third-party inference**。

### 2. 填写 UseGoodAI Gateway

在 **Connection** 中填写：

| 字段 | 填写 |
| --- | --- |
| Inference provider | `Gateway` |
| Gateway base URL | `https://api.usegoodai.com` |
| Credential kind | `Static API key` |
| Gateway API key | UseGoodAI API Key |
| Gateway auth scheme | `Bearer` |

Gateway base URL 不要添加 `/v1`。Claude Desktop 会自动请求 Anthropic Messages API，UseGoodAI 在服务端完成协议处理和模型映射。

### 3. 应用配置并测试

点击 **Apply locally**。Claude Desktop 会重新启动，在登录页选择使用第三方配置进入。

发送：

```text
测试
```

能正常回复后，直接使用 APP 内的模型选择器切换模型，不需要新开对话。

## 配置 Claude Code CLI

### 1. 设置当前终端

在 macOS、Linux 或 WSL 终端执行：

```bash
export ANTHROPIC_BASE_URL="https://api.usegoodai.com"
export ANTHROPIC_AUTH_TOKEN="你的 UseGoodAI API Key"
claude
```

这两个环境变量只对当前终端生效。关闭终端后，下次使用前重新执行。

### 2. 测试并切换模型

进入 Claude Code CLI 后发送：

```text
测试
```

能正常回复后，在当前会话输入 `/model`，直接切换模型，不需要新开对话。

## Claude 模型如何映射到 GPT-5.6

Claude Desktop 和 Claude Code CLI 仍然显示 Claude 模型名称。请求到达 UseGoodAI 后，服务端按照下面的关系调用 GPT-5.6：

| 客户端选择 | UseGoodAI 实际调用 |
| --- | --- |
| `Opus 4.7` | `GPT-5.6 Sol` |
| `Sonnet 4.7` | `GPT-5.6 Terra` |
| `Haiku 4.7` | `GPT-5.6 Luna` |

客户端只需选择 `Opus 4.7`、`Sonnet 4.7` 或 `Haiku 4.7`。不要在 APP 或 CLI 里另外填写 `GPT-5.6 Sol`、`GPT-5.6 Terra`、`GPT-5.6 Luna`，也不需要设置 `ANTHROPIC_MODEL` 或 `ANTHROPIC_DEFAULT_*_MODEL`。

## 排查

| 现象 | 处理 |
| --- | --- |
| APP 找不到第三方推理入口 | 回到登录页，按 **Help → Troubleshooting → Enable Developer Mode** 开启后再进入 **Developer** 菜单 |
| APP 应用配置后仍显示普通登录页 | 彻底退出并重新打开 APP，再选择第三方配置入口 |
| CLI 仍在使用原来的服务 | 确认在执行 `export` 的同一个终端里启动了 `claude` |
| `401 Unauthorized` | 重新复制 UseGoodAI API Key，确认 APP 使用 `Bearer`，CLI 使用 `ANTHROPIC_AUTH_TOKEN` |
| 请求地址错误 | APP 和 CLI 都只填 `https://api.usegoodai.com`，不要添加 `/v1` |
| 切换模型后没有变化 | APP 检查模型选择器，CLI 重新输入 `/model`，确认选择的是对应的 4.7 模型 |

## 切回默认服务

Claude Desktop 回到登录页，选择 Anthropic 登录入口。

Claude Code CLI 关闭当前终端，或执行：

```bash
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN
```
