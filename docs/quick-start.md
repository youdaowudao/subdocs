---
title: 快速开始
---

# 快速开始

本文适合第一次在 Windows 的 Codex App 接入 UseGoodAI。完成后，Codex 的模型请求会走中转站；脚本只写入本机 `~/.codex/config.toml` 和 `~/.codex/auth.json`，并自动备份旧文件。

开始前确认：

- 已安装 ChatGPT / Codex App；还没安装先看 [Codex 接入](/clients/codex)。
- 已能登录 UseGoodAI 后台。
- 账户有可用余额；余额不足时接入能完成，但测试会失败。

## 1. 创建本中转站的 API 密钥

进入后台 **API 密钥**，点击 **创建密钥**。名称写用途，分组选当前要用的模型档位，创建后复制 API Key。

API Key 用来让 Codex 识别你的账户和扣费，后面脚本会要求你粘贴这个 Key。

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

## 2. 打开 PowerShell 运行脚本

Windows 按 `Win + X`，点击 **终端** 或 **Windows PowerShell**。

在打开的窗口里粘贴运行：

```powershell
irm https://docs.usegoodai.com/install/codex.ps1 | iex
```

脚本要求输入 API Key 时，粘贴第 1 步复制的 Key，然后按回车。

<details>
<summary>Mac 用户看这里</summary>

打开终端运行：

```bash
curl -fsSL https://docs.usegoodai.com/install/codex.sh | bash
```

脚本要求输入 API Key 时，粘贴第 1 步复制的 Key，然后按回车。

</details>

提示未检测到 Codex App 时，先安装 Codex App，再运行脚本。

## 3. 关闭并重新打开 Codex

脚本完成后，彻底退出 Codex App，再重新打开并新建任务。

Windows 配置未生效时，用任务管理器结束所有 `ChatGPT` 进程，再打开 Codex。

发送 `测试`。

能正常回复，就接入完成。

## 4. 查看模型价格

接入完成后，模型价格和分组在 [模型价格](/models) 查看。实际扣费以后台使用记录为准。

## 快速开始失败先看这里

| 你看到的情况 | 先做这一件事 | 还不行 |
| --- | --- | --- |
| 不知道命令粘贴到哪里 | 按 `Win + X`，打开 **终端** 或 **Windows PowerShell** | 回到第 2 步重新复制命令 |
| 脚本提示未检测到 Codex App | 先安装 Codex App，再回到本页重新运行脚本 | 看 [Codex 接入](/clients/codex) |
| 脚本完成后 Codex 仍没反应 | 彻底退出 Codex；Windows 用任务管理器结束所有 `ChatGPT` 进程，再重新打开 | 看 [报错与踩坑](/errors/) |
| 出现 `401` / `Unauthorized` | 回后台重新复制 API Key，再运行脚本 | 看 [报错与踩坑](/errors/) |
| 出现 `403` / `model not found` | 回后台确认 API Key 所属分组支持当前模型 | 看 [报错与踩坑](/errors/) |
| 出现 `429` / `insufficient_quota` | 登录后台查看余额，充值后重新测试 | 看 [报错与踩坑](/errors/) |

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
