---
sidebarTitle: Antigravity App / CLI
---

# Antigravity App 和 CLI 接入

Antigravity 是 Google 的 AI Agent 工具，可以帮你编程、修改文件、运行命令和完成复杂任务。**App** 是图形界面的独立桌面软件，**CLI** 是终端里的 `agy` 命令；本文不讲独立 Antigravity IDE，也不讲 Gemini CLI。

下面将官方 App 或 CLI 接入 UseGoodAI 的 Gemini 原生接口。Windows 只写当前用户环境变量；Mac/Linux 的 App 保存用户接入配置，CLI 更新终端启动配置，不修改官方软件本身。无需管理员权限。

## 1. 安装官方软件

到 [Antigravity 官网下载页](https://antigravity.google/download)，选择 **Antigravity App** 或 **Antigravity CLI** 安装。

在 UseGoodAI 的 **API 密钥** 页复制 Gemini 分组的完整密钥（创建方法见 [快速开始](/quick-start#_1-创建-api-key)）。

## 2. Windows 一键接入

1. [下载 UseGoodAI 中转快速接入助手](/download/usegoodai-quick-connect-windows-x64.exe)，双击打开。提示“已保护你的电脑”时点「更多信息」→「仍要运行」。
2. 切换到 **Antigravity**，粘贴 Gemini 分组的密钥，点「一键连接 Antigravity」。
3. App：彻底退出后重新打开；CLI：关闭并重新打开终端，运行 `agy`。两者共用本次接入配置，不必重复配置。

## 3. Mac / Linux 终端接入

### 使用 App

彻底退出 Antigravity App，在终端粘贴下面的命令并回车：

```bash
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash
```

粘贴 Gemini 分组的密钥，接入程序会保存配置并打开 App。Linux 若没有在常用目录找到 App，粘贴官方 App 的实际解压目录即可，只需填写一次。

以后要打开已接入的 App，运行：

```bash
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- open
```

Mac 也可用 [中转快速接入助手](/download/usegoodai-quick-connect-mac-arm64.zip)，首次打开在「系统设置 → 隐私与安全性」点「仍要打开」，再选择 Antigravity，按菜单连接或打开。

### 使用 CLI

在终端运行下面的命令，粘贴 Gemini 分组的密钥：

```bash
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- cli
```

关闭并重新打开终端，运行 `agy` 即可。Mac/Linux 的 App 与 CLI 接入分别保存，不需要为了使用 CLI 而安装 App。

## 4. 发送测试消息

新建对话或任务，发送 `测试`。能收到回复，并在 UseGoodAI 的使用记录中看到本次调用，即可确认接入成功。

## 恢复官方登录

Windows 在助手的 Antigravity 页面点「恢复官方登录」，重新打开 App 或终端。

Mac/Linux 在终端执行对应命令：

```bash
# 恢复 App
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- restore
# 恢复 CLI
curl -fsSL https://docs.usegoodai.com/install/antigravity.sh | bash -s -- cli-restore
```

彻底退出并重新打开 App，或关闭并重新打开终端后运行 `agy`，即可使用原来的登录方式。
