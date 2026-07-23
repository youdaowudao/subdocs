---
title: 快速开始
---

# 快速开始

首先安装好 Codex App，粘贴运行本站一键配置脚本命令，即可快速接入本中转站，无任何难度。

## 1. 先创建本中转站的 API 密钥

进入后台 **API 密钥**，点击 **创建密钥**。名称写用途，分组选模型档位，创建后复制 API Key。

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

## 2. 复制粘贴以下命令运行

Windows 打开 PowerShell，复制粘贴以下命令运行：

```powershell
irm https://docs.usegoodai.com/install/codex.ps1 | iex
```

Mac 打开终端运行：

```bash
curl -fsSL https://docs.usegoodai.com/install/codex.sh | bash
```

脚本要求输入 API Key 时，粘贴第一步复制的 Key。

提示未检测到 Codex App 时，先安装 Codex App，再运行脚本。

## 3. 关闭并重新打开 Codex

脚本完成后，彻底退出 Codex App，再重新打开并新建任务。

Windows 配置未生效时，用任务管理器结束所有 `ChatGPT` 进程，再打开 Codex。

发送 `测试`。

能正常回复，就接入完成。

<details>
<summary>脚本提示未检测到 Codex App</summary>

先安装 Codex App。回到本页重新运行脚本。

</details>

<details>
<summary>脚本安全吗？</summary>

脚本开源，源码会放在公开仓库：

```text
https://github.com/usegoodai/usegoodai-codex-installer
```

本脚本仅仅只是为了方便不会配置文件的用户，只修改本机 Codex 配置中的以下两个文件，不会有其他操作。如果不放心，请采取后面的其他配置方法。

| 文件 | 作用 |
| --- | --- |
| `~/.codex/config.toml` | 写入 UseGoodAI 接口地址、模型和 Responses 配置 |
| `~/.codex/auth.json` | 写入 UseGoodAI API Key |

写入前会自动备份旧文件。

</details>

## 其它配置方式

| 顺序 | 方式 | 入口 |
| --- | --- | --- |
| 第二种 | CC Switch 接入 | [Codex CC Switch 接入](/codex-cc-switch) |
| 第三种 | 手动配置 | [Codex 手动接入](/clients/codex-manual-config) |
