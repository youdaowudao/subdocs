---
title: 快速开始
---

# 快速开始

本页把 Codex App 接入 UseGoodAI：把本中转站的接口地址和 API Key 写进本机 `.codex` 文件夹里的 `config.toml` 和 `auth.json`，之后 Codex 的请求走本中转站，按用量扣费。推荐用接入助手在后台一键导入；助手没反应时改用命令行。

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

<a id="quick-connect-helper"></a>

## 2. 用接入助手一键导入

导入会备份并替换原有 Codex 配置，完成后自动关闭 ChatGPT 软件和 Codex。先结束正在进行的任务。

1. 下载并打开一次接入助手：[下载 Windows 接入助手](/download/usegoodai-quick-connect-windows-x64.exe)。Mac（Apple 芯片）下载 [Mac 版](/download/usegoodai-quick-connect-mac-arm64.zip)，解压后双击 `UseGoodAI中转快速接入助手.app`。后台首页「快速开始」第 3 步也有这两个下载按钮。
   - Windows 提示“Windows 已保护你的电脑”时，点 **更多信息** → **仍要运行**。
   - Mac 第一次打开被拦下时，到 **系统设置 → 隐私与安全性** 点 **仍要打开**；提示要控制“终端”时点 **允许**。
2. 在后台点 **一键导入 Codex**，两处任选：
   - 首页「快速开始」第 3 步：在下拉框选第 1 步创建的密钥，点 **一键导入 Codex**。
   - **API 密钥** 页面：在要用的密钥那一行，点「操作」列的 **一键导入 Codex**。
3. 浏览器询问是否打开助手时，点 **打开**。助手先向服务器确认 Key 可用，再写入配置并关闭 Codex。Windows 在助手窗口里显示结果；Mac 在终端里显示，结束后按回车关闭。

助手开着或关着都能导入。也可以不经过网页：复制 Key 后打开助手，Windows 会自动填入，点 **一键连接 Codex**；Mac 会读取剪贴板里的 Key。

Windows 助手顶部显示当前连接的 Key（中间部分遮住，网页导入的还显示 Key 名称）。右下角 **恢复官方登录** 会取消中转站连接，改回官方账号登录。

## 3. 重新打开 Codex 测试

重新打开 Codex，新建任务，发送 `测试`。能正常回复，就接入完成。

<a id="_2-运行接入命令"></a>
<a id="command-line"></a>

## 助手没反应？用命令行接入

命令和助手写入的配置完全一样，同样会备份原配置，完成后自动关闭 ChatGPT 软件和 Codex。

Windows 按 `Win + X`，点击 **终端** 或 **Windows PowerShell**；Mac 打开 **终端**。粘贴对应命令运行：

::: code-group

```powershell [Windows]
irm https://docs.usegoodai.com/install/codex.ps1 | iex
```

```bash [Mac]
curl -fsSL https://docs.usegoodai.com/install/codex.sh | bash
```

:::

看到输入 API Key 的提示时，回后台 **API 密钥** 页面复制第 1 步的 Key，粘贴后按回车。完成后按第 3 步测试。

<a id="运行脚本遇到问题"></a>

## 遇到问题

| 遇到的问题 | 处理方法 |
| --- | --- |
| 点 **一键导入 Codex** 后浏览器没有询问，也没有反应 | 先下载并打开一次助手，再回后台点；仍没反应，用 [命令行接入](#command-line) |
| Windows 提示需要安装 Microsoft Edge WebView2 运行库 | 点 **确定** 打开微软下载页，安装后重新打开助手；不想装就用 [命令行接入](#command-line) |
| Mac 提示另一个快速接入助手窗口正在配置 Codex | 先在那个终端窗口完成或关闭它，再点一次 **一键导入 Codex** |
| 提示无法下载脚本 | 检查网络后重新运行命令；仍然失败，改用下面的 CC Switch 接入 |
| 提示密钥格式不对（`必须以 sk- 开头` 或 `这不是 UseGoodAI 的密钥`） | 回后台 **API 密钥** 页面重新复制完整 Key；示范图里带 `****` 的 Key 不能用 |
| 提示 `密钥无效` 或 `已停用、过期或额度用完` | 回后台 **API 密钥** 页面换一个可用的 Key 再导入 |
| 提示 `网络超时`、`连不上 UseGoodAI 服务器` 或 `服务器暂时出错` | Windows 助手这时不会改配置，检查网络或代理后再点一次。命令行和 Mac 助手会继续写入，照第 3 步测试；不能回复就检查网络或代理后重新导入 |
| Codex 提示 `INSUFFICIENT_BALANCE` 或 `Insufficient account balance` | 充值后重新测试；仍然提示，重新导入已充值账号的 Key |
| 提示没能自动关闭 Codex | 手动彻底退出 Codex 后重新打开；仍不行就重启电脑 |
| Codex 返回其他报错 | 看 [报错与踩坑](/errors/) |

<details>
<summary>改了哪些文件</summary>

助手和命令都只替换两个文件，不安装、不修改其他软件：

- `config.toml`：UseGoodAI 接口地址和模型
- `auth.json`：UseGoodAI API Key

两个文件都在 `C:\Users\你的用户名\.codex\`（Mac 为 `~/.codex/`），旧文件备份为同目录下的 `.bak.时间戳` 文件。原来配过 MCP 的，从备份里把 MCP 配置复制回 `config.toml`。

</details>

<details>
<summary>移除中转配置，恢复官方账号登录</summary>

Windows 助手点右下角 **恢复官方登录** 即可。也可以运行命令：

::: code-group

```powershell [Windows]
irm https://docs.usegoodai.com/install/codex-restore.ps1 | iex
```

```bash [Mac]
curl -fsSL https://docs.usegoodai.com/install/codex-restore.sh | bash
```

:::

两种方式都会清空登录凭据，并删除 `config.toml` 中的模型端点配置；MCP 和其它配置保持不变。完成后彻底退出 Codex，重新打开并使用官方账号登录。

</details>

## 其他接入方式

| 方式 | 什么时候用 |
| --- | --- |
| QQ 群交付包 | 网站下载慢时，在 <span style="color: #d93025;"><strong>QQ 群：1020015031</strong></span> 群文件下载 `中转站快速导入工具.zip`，解压后用 `1.UseGoodAI中转快速接入助手`，用法同第 2 步 |
| [CC Switch 接入](/codex-cc-switch) | 助手和命令都不行，或需要在官方账号和中转站之间来回切换 |
| [手动配置](/codex/manual-config) | 不想运行程序和脚本，自己修改配置文件 |

## 接下来

- 查看 [模型价格](/models) 了解各分组价格，实际扣费以后台使用记录为准。
- 想在 Codex 里生成和修改图片：为图片模型另建一个 **专门画图分组** 的 API Key，按 [安装生图工具](/image-video-group-image) 完成安装。
