---
title: 快速开始
---

# 快速开始

先装好 Codex App（[安装方法](/codex/)），再按下面 4 步接入 Codex 和生图工具。

<a id="_1-创建-api-key"></a>

## 1. 创建两把密钥

后台 **API 密钥** → **创建密钥**，建下面两把，名称随意填：

| 分组 | 用途 |
| --- | --- |
| GPT 开头的分组 | Codex 对话 |
| 专门画图分组 | 在 Codex 里生图 |

<details>
<summary>截图</summary>

<a class="doc-image-link" href="/images/quick-start/create-api-key-1.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-1.jpg" alt="进入 API 密钥页面并点击创建密钥">
</a>

<a class="doc-image-link" href="/images/quick-start/create-api-key-2.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-2.jpg" alt="填写密钥名称并选择正确分组">
</a>

<a class="doc-image-link" href="/images/画图/画图专用分组.jpg" target="_blank" rel="noopener">
  <img src="/images/画图/画图专用分组.jpg" alt="在 API 密钥列表核对专门画图分组的密钥">
</a>

</details>

<a id="quick-connect-helper"></a>

## 2. 进群下载助手

1. 加 QQ 群 <span style="color: #d93025;"><strong>1020015031</strong></span>。新人进群私发账号邮箱给群主，领 2 元。
2. 在群文件下载 `中转站快速导入工具`，解压后双击 `1.UseGoodAI中转快速接入助手`。提示“已保护你的电脑”时点 **更多信息** → **仍要运行**。

助手打开过一次，网站的一键导入才能用。

<a id="helper-powershell"></a>

<details>
<summary>不想进群下载？用 PowerShell 打开助手</summary>

1. 按 `Win + X` 打开 **终端**（Win10 叫 **Windows PowerShell**）。
2. 粘贴下面命令，回车：

```powershell
irm https://docs.usegoodai.com/install/helper.ps1 | iex
```

3. 助手下载到桌面并自动打开。以后双击桌面上的 `UseGoodAI中转快速接入助手` 也能打开。下载失败时，窗口里会提示去群文件下载。

</details>

## 3. 一键导入

回后台 **API 密钥** 页，在密钥那一行的「操作」列点：

1. Codex 那把：**一键导入 Codex**。
2. 画图那把：**一键导入**。

浏览器问是否打开时点 **打开**。导入 Codex 会先自动关闭 Codex，先保存正在进行的任务。

<a id="_3-重新打开-codex-测试"></a>

## 4. 发送测试消息

重新打开 Codex，新建任务，发送 `测试`，能回复说明 Codex 接好了；再发送 `画一张白底红苹果`，对话里出现图片说明生图也装好了。

<a id="运行脚本遇到问题"></a>
<a id="_2-运行接入命令"></a>
<a id="command-line"></a>

## 遇到问题

| 提示或现象 | 怎么办 |
| --- | --- |
| 点 **一键导入** 没反应 | 先双击打开一次助手再点。还不行就复制密钥粘贴进助手：Codex 那把点 **一键连接 Codex**；画图那把点助手下方 **Codex 生图工具**，再点 **一键导入生图工具** |
| 要安装 WebView2 运行库 | 点 **确定** 下载安装 |
| 助手提示电脑的日期时间不对，或 PowerShell 提示「未能为 SSL/TLS 安全通道建立信任关系」 | 右键任务栏右下角的时间，选 **调整日期和时间**，打开 **自动设置时间**，点 **立即同步**，再试一次。时间正确还报错看 [证书报错](/errors/#ssl-trust) |
| 密钥格式不对 | 回后台重新复制完整密钥（带 `****` 的是遮挡过的，不能用） |
| 密钥无效、已停用、过期或额度用完 | 换一把可用的密钥 |
| 提示余额不足，或 Codex 报 `INSUFFICIENT_BALANCE` | 后台首页点 **去充值**，再试一次 |
| 网络超时、连不上服务器、服务器出错 | 检查网络或代理后重试 |
| 没能自动关闭 Codex | 手动退出 Codex 再打开，不行就重启电脑 |
| 发 `画一张白底红苹果` 没出图 | 完全退出 Codex 再打开，新建任务再发 |
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

助手右下角点 **恢复官方登录**。没有助手时，在 PowerShell 运行：

```powershell
irm https://docs.usegoodai.com/install/codex-restore.ps1 | iex
```

会清空登录凭据和中转站的接口配置，MCP 等其它配置不动。之后重新打开 Codex，用官方账号登录。

</details>

## 接下来

- [导入国产模型](/codex-models)：把国产模型加进 Codex 的模型菜单，和 GPT 来回切换。
- [Codex 改中文版](/codex-chinese)：没有梯子时把 Codex 界面改成中文。
- [安装生图工具](/image-video-group-image)：生图的常用说法、支持的模型和 GIF 动图。
- [CC Switch 接入](/codex-cc-switch)：在官方账号和中转站之间来回切。
- [Claude Desktop 接入](/claude/desktop)：用助手一键连接 Claude 桌面版。
- [Antigravity 接入](/clients/antigravity)：用 Gemini 分组的密钥接入反重力 App 和 CLI。
- [手动配置](/codex/manual-config)：自己改配置文件。
- [模型价格](/models)

<a id="mac"></a>

## Mac 接入

Mac 没有接入助手。先做第 1 步建两把密钥、进 QQ 群领 2 元，再在终端导入：

1. 按 `Command + 空格`，输入「终端」，回车。
2. 粘贴下面命令，回车。提示输入 API Key 时，粘贴 Codex 那把密钥，回车：

```bash
curl -fsSL https://docs.usegoodai.com/install/codex.sh | bash
```

3. 再粘贴这条命令，回车。提示输入 Key 时，粘贴画图那把密钥，回车：

```bash
curl -fsSL https://docs.usegoodai.com/install/usegoodai-imagines-tool/install.sh | bash
```

完成后做第 4 步。提示另一个窗口正在配置 Codex 时，先把那个终端窗口走完或关掉。

改回官方账号登录时，在终端运行：

```bash
curl -fsSL https://docs.usegoodai.com/install/codex-restore.sh | bash
```
