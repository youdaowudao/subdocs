---
title: 快速开始
---

# 快速开始

本页用一条命令把 Codex App 接入 UseGoodAI：脚本把本中转站的接口地址和 API Key 写进本机 `.codex` 文件夹里的 `config.toml` 和 `auth.json`，之后 Codex 的请求走本中转站，按用量扣费。

开始前需要已安装 Codex App（未安装先看 [Codex 接入](/codex/)），账号有余额。

## 1. 创建 API Key

进入管理后台 **API 密钥**，点击 **创建密钥**。名称写用途，分组选 GPT 开头的分组，创建后复制 API Key。

<details>
<summary>查看创建和复制截图</summary>

<a class="doc-image-link" href="/images/quick-start/create-api-key-1.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-1.jpg" alt="进入 API 密钥页面并点击创建密钥">
</a>

<a class="doc-image-link" href="/images/quick-start/create-api-key-2.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-2.jpg" alt="填写密钥名称并选择正确分组">
</a>

<a class="doc-image-link" href="/images/quick-start/create-api-key-3.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-3.jpg" alt="在 API 密钥列表中复制 API Key">
</a>

</details>

## 2. 运行接入命令

脚本会备份并替换原有 Codex 配置，完成后自动关闭 ChatGPT 软件和 Codex。运行前先结束正在进行的任务。

Windows 按 `Win + X`，点击 **终端** 或 **Windows PowerShell**；Mac 打开 **终端**。粘贴对应命令运行：

::: code-group

```powershell [Windows]
irm https://docs.usegoodai.com/install/codex.ps1 | iex
```

```bash [Mac]
curl -fsSL https://docs.usegoodai.com/install/codex.sh | bash
```

:::

看到输入 API Key 的提示时，粘贴第 1 步复制的 Key，按回车。

## 3. 重新打开 Codex 测试

重新打开 Codex，新建任务，发送 `测试`。能正常回复，就接入完成。

## 运行脚本遇到问题

| 遇到的问题 | 处理方法 |
| --- | --- |
| 提示无法下载脚本 | 检查网络后重新运行第 2 步命令；仍然失败，改用下面的 CC Switch 接入 |
| 提示 `API Key 格式错误，必须以 sk- 开头` | 回到后台 **API 密钥** 页面重新复制完整 Key，再粘贴 |
| Codex 提示 `INSUFFICIENT_BALANCE` 或 `Insufficient account balance` | 充值后重新测试；仍然提示，重新运行第 2 步，粘贴已充值账号的 Key |
| 提示未能自动关闭 | 重启电脑，打开 Codex 新建任务测试 |
| Codex 返回其他报错 | 看 [报错与踩坑](/errors/) |

<details>
<summary>脚本改了哪些文件</summary>

脚本只替换两个文件，不安装、不修改其他软件：

- `config.toml`：UseGoodAI 接口地址和模型
- `auth.json`：UseGoodAI API Key

两个文件都在 `C:\Users\你的用户名\.codex\`（Mac 为 `~/.codex/`），旧文件备份为同目录下的 `.bak.时间戳` 文件。原来配过 MCP 的，从备份里把 MCP 配置复制回 `config.toml`。

</details>

<details>
<summary>移除中转配置，恢复官方账号登录</summary>

::: code-group

```powershell [Windows]
irm https://docs.usegoodai.com/install/codex-restore.ps1 | iex
```

```bash [Mac]
curl -fsSL https://docs.usegoodai.com/install/codex-restore.sh | bash
```

:::

脚本会清空登录凭据，并删除 `config.toml` 中的模型端点配置；MCP 和其它配置保持不变。完成后彻底退出 Codex，重新打开并使用官方账号登录。

</details>

## 其他接入方式

| 方式 | 什么时候用 |
| --- | --- |
| QQ 群运行版 | 不想用 PowerShell。加入 <span style="color: #d93025;"><strong>QQ 群：1020015031</strong></span>，在群文件下载后解压，双击 `Codex接入配置.exe`，按提示粘贴 API Key |
| [CC Switch 接入](/codex-cc-switch) | 脚本下载失败，或需要在官方账号和中转站之间来回切换 |
| [手动配置](/codex/manual-config) | 不想运行脚本，自己修改配置文件 |

## 接下来

- 查看 [模型价格](/models) 了解各分组价格，实际扣费以后台使用记录为准。
- 想在 Codex 里生成和修改图片：为图片模型另建一个 **专门画图分组** 的 API Key，按 [安装生图工具](/image-video-group-image) 完成安装。
