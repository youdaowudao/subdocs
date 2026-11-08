---
title: 快速开始
---

# 快速开始

先装好 Codex App（[安装方法](/codex/)），再按下面 4 步接入。

<a id="_1-创建-api-key"></a>

## 1. 创建密钥

后台 **API 密钥** → **创建密钥**。名称随意填，比如「测试」；分组选 GPT 开头的。

<details>
<summary>截图</summary>

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

## 2. 充值

后台首页点 **去充值**。新人加 <span style="color: #d93025;"><strong>QQ 群：1020015031</strong></span> 领 2 元。

<a id="quick-connect-helper"></a>

## 3. 连接 Codex

1. 先打开一次接入助手。进 QQ 群 <span style="color: #d93025;"><strong>1020015031</strong></span>，在群文件下载 `中转站快速导入工具`，解压后双击 `1.UseGoodAI中转快速接入助手`（Mac 在 `Mac-Apple芯片` 文件夹里）。Windows 也可以[用 PowerShell 命令下载并打开](#helper-powershell)。
2. 回后台点 **一键导入 Codex**：首页第 3 步选好密钥点，或在 **API 密钥** 页那把密钥的「操作」列点。
3. 浏览器问是否打开时，点 **打开**。

<a id="helper-powershell"></a>

<details>
<summary>Windows：用 PowerShell 命令下载并打开助手</summary>

1. 按 `Win + X` 打开 **终端**（Win10 叫 **Windows PowerShell**）；也可以点开始菜单，往下拉找到 **Windows PowerShell** 打开。
2. 点下面命令右上角的复制按钮，粘贴到窗口里，回车：

```powershell
irm https://docs.usegoodai.com/install/helper.ps1 | iex
```

3. 窗口里刷出几行字后，助手会下载到桌面并自动弹出来，回后台点 **一键导入 Codex** 即可。以后双击桌面上的 `UseGoodAI中转快速接入助手` 也能打开。

下载失败时，窗口里会提示去群文件下载。

</details>

导入时会先自动关闭 Codex，先保存正在进行的任务。

打不开助手时：Windows 点 **更多信息** → **仍要运行**；Mac 到 **系统设置 → 隐私与安全性** 点 **仍要打开**，问到控制“终端”时点 **允许**。

不用网页也行：复制密钥后打开助手，Windows 点 **一键连接 Codex**，Mac 会直接读取剪贴板。

<a id="_3-重新打开-codex-测试"></a>

## 4. 发送第一条消息

重新打开 Codex，新建任务，发送 `测试`。能回复就接入完成了。

<a id="_2-运行接入命令"></a>
<a id="command-line"></a>

## 没反应？用 PowerShell 命令行

按 `Win + X`，打开 **终端**，粘贴命令回车（Mac 打开 **终端**，用 Mac 那行）：

::: code-group

```powershell [Windows]
irm https://docs.usegoodai.com/install/codex.ps1 | iex
```

```bash [Mac]
curl -fsSL https://docs.usegoodai.com/install/codex.sh | bash
```

:::

提示输入 API Key 时，粘贴第 1 步的密钥，回车。完成后做第 4 步。

<a id="运行脚本遇到问题"></a>

## 遇到问题

| 提示或现象 | 怎么办 |
| --- | --- |
| 点 **一键导入 Codex** 没反应 | 先打开一次助手再点；还不行用 [命令行](#command-line) |
| PowerShell 命令提示下载或打开失败 | 进 QQ 群 1020015031，在群文件下载 `中转站快速导入工具`，解压后打开 `1.UseGoodAI中转快速接入助手` |
| PowerShell 提示「未能为 SSL/TLS 安全通道建立信任关系」，或助手提示电脑的日期时间不对 | 电脑时间不对：右键任务栏右下角的时间，选 **调整日期和时间**，打开 **自动设置时间**，点 **立即同步**，再运行一次命令。时间正确还报错看 [证书报错](/errors/#ssl-trust) |
| 要安装 WebView2 运行库 | 点 **确定** 下载安装，或改用 [命令行](#command-line) |
| 密钥格式不对 | 回后台重新复制完整密钥（带 `****` 的是遮挡过的，不能用） |
| 密钥无效、已停用、过期或额度用完 | 换一把可用的密钥 |
| 网络超时、连不上服务器、服务器出错 | 检查网络或代理后重试。命令行这时仍会写入，可以直接做第 4 步试试 |
| 命令提示无法下载脚本 | 检查网络后重试，或改用 [CC Switch](/codex-cc-switch) |
| Mac：另一个窗口正在配置 Codex | 先把那个终端窗口走完或关掉 |
| 没能自动关闭 Codex | 手动退出 Codex 再打开，不行就重启电脑 |
| Codex 报 `INSUFFICIENT_BALANCE` 或 `Insufficient account balance` | 充值后重试 |
| 其他报错 | 看 [报错与踩坑](/errors/) |

<details>
<summary>改了哪些文件</summary>

只改 `C:\Users\你的用户名\.codex\`（Mac 为 `~/.codex/`）里的两个文件：

- `config.toml`：写入接口地址和模型；去掉以前写入的完全访问设置和其它接口，MCP、插件、项目信任、沙箱设置等其余设置保留
- `auth.json`：密钥

旧文件备份在同目录，文件名带 `.bak.时间戳`。

</details>

<details>
<summary>改回官方账号登录</summary>

Windows 助手点右下角 **恢复官方登录**；或者运行：

::: code-group

```powershell [Windows]
irm https://docs.usegoodai.com/install/codex-restore.ps1 | iex
```

```bash [Mac]
curl -fsSL https://docs.usegoodai.com/install/codex-restore.sh | bash
```

:::

会清空登录凭据和中转站的接口配置，MCP 等其它配置不动。之后重新打开 Codex，用官方账号登录。

</details>

## 其他方式

- 要在官方账号和中转站之间来回切：[CC Switch 接入](/codex-cc-switch)。
- 接入 Claude 桌面版（Windows 助手也能一键连接）：[Claude Desktop 接入](/claude/desktop)。
- 自己改配置文件：[手动配置](/codex/manual-config)。

## 接下来

- [模型价格](/models)
- 在 Codex 里生图：另建一把 **专门画图分组** 的密钥，按 [安装生图工具](/image-video-group-image) 安装。
