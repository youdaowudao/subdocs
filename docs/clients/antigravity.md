---
sidebarTitle: Antigravity
---

# Antigravity（反重力）接入

Antigravity（反重力）是 Google 的 AI Agent 工具，可以编程、修改文件和运行命令。**App** 是桌面版，**CLI** 是终端命令 `agy`，两者都能用 UseGoodAI 的 Gemini 模型；本文不讲 Antigravity IDE 或 Gemini CLI。

接入助手和命令只修改当前用户的环境变量或接入配置（`connection.json`、终端启动配置），无需管理员权限。

## 1. 安装软件

到 [官网下载](https://antigravity.google/download) 安装 **Antigravity App** 或 **Antigravity CLI**。在中转站的 **API 密钥** 页复制 Gemini 分组的密钥。

## 2. Windows 一键接入

1. [下载接入助手](/download/usegoodai-quick-connect-windows-x64.exe)，双击打开（提示“已保护你的电脑”时，点「更多信息」→「仍要运行」），点右上角 **Antigravity**。
2. 粘贴 Gemini 分组的密钥，点 **一键连接 Antigravity**。
3. App 彻底退出后重新打开；CLI 重开终端运行 `agy`。

Windows 上 App 和 CLI 共用配置，已经接入 App 的用户不需要再次配置 CLI。

## 3. Mac / Linux 终端接入

### App 桌面版

彻底退出 App，在终端运行：

```bash
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash
```

粘贴密钥，配置好后会打开 App。Linux 若提示找不到 App，粘贴解压后的文件夹路径（只需填写一次）。

以后用这条命令打开 App：

```bash
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- open
```

Mac 也可用 [接入助手](/download/usegoodai-quick-connect-mac-arm64.zip)，首次打开在「系统设置 → 隐私与安全性」点「仍要打开」，然后选择 Antigravity。

### CLI 终端版

在终端运行：

```bash
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- cli
```

粘贴密钥，重新打开终端运行 `agy`。Mac/Linux 上 App 和 CLI 各自配置一次，不需要同时安装两种软件。

## 4. 测试

新建对话，发送 `测试`，能回复并在使用记录中看到调用就接入成功了。

<details>
<summary>恢复官方登录</summary>

Windows 在助手的 Antigravity 页面点 **恢复官方登录**。

Mac/Linux 在终端执行对应命令：

```bash
# 恢复 App
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- restore
# 恢复 CLI
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- cli-restore
```

重新打开 App 或终端即可使用原来的登录方式。

</details>
