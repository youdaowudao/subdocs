# 用 CC Switch 管理 UseGoodAI 配置

CC Switch 是桌面配置管理工具，用来统一管理 Codex、Gemini CLI、OpenClaw、Hermes 等 Agent / CLI 客户端的供应商配置。它不提供模型，只负责把 UseGoodAI 的 API Key、模型名和接口地址写进目标客户端配置。

本文适合同时使用多个客户端、想集中切换配置的用户。只想先跑通 Codex 时，先看 [快速开始](/quick-start)。

## 安装 CC Switch

官方项目地址：<https://github.com/farion1231/cc-switch>

| 系统 | 安装方式 |
| --- | --- |
| Windows | 到 Releases 下载 `Windows.msi` 或 `Windows-Portable.zip` |
| macOS | 用 Homebrew 安装，或到 Releases 下载 `.dmg` |
| Arch Linux | 安装 AUR 包 `cc-switch-bin` |
| 其它 Linux | 到 Releases 下载 `.deb`、`.rpm` 或 `.AppImage` |

macOS 已安装 Homebrew 时运行：

```bash
brew install --cask cc-switch
```

Arch Linux 运行：

```bash
paru -S cc-switch-bin
```

## 添加 UseGoodAI 配置

打开 CC Switch，点击 **添加配置** 或 **添加供应商**，选择要管理的目标客户端。

| 目标客户端 | 在 CC Switch 里对应什么 |
| --- | --- |
| Codex | Codex 的供应商 / API 配置 |
| OpenClaw | OpenClaw 的 provider 配置 |
| Hermes | Hermes Agent 的模型配置 |
| 其它工具 | 按 CC Switch 当前支持列表选择 |

没有明确写给 UseGoodAI 的模板时，选择自定义供应商或自定义接口，不要套用其它站点模板。

## 填写参数

| 字段 | 填写 |
| --- | --- |
| Provider / 供应商名称 | `UseGoodAI` |
| API Key | UseGoodAI API Key |
| Model | 当前 Key 分组可用模型，例如 `gpt-5.5` |
| Base URL | 普通手动配置填 `https://api.usegoodai.com/v1`；后台或工具已经生成配置时，直接用生成结果 |

手动填写 Base URL 时只填到 `/v1`，不要追加其它路径。

## 启用并测试

保存后，在 CC Switch 里启用刚才创建的配置。

| 客户端类型 | 生效方式 |
| --- | --- |
| CLI 工具 | 关闭并重新打开终端，再启动客户端 |
| 桌面客户端 | 彻底退出后重新打开 |
| 后台常驻进程 | 重启对应进程或网关 |

打开目标客户端，发送：

```text
用一句话回复：当前客户端已经通过 UseGoodAI 连接成功。
```

能正常回复，说明目标客户端已经读取 CC Switch 启用的配置。

## 常见错误

| 现象 | 处理 |
| --- | --- |
| 客户端仍使用旧模型 | 确认 CC Switch 当前启用的是 UseGoodAI 配置，并重启目标客户端 |
| 模型报错 | 换成当前 Key 分组里的完整模型名 |
| `401 Unauthorized` | 重新复制 API Key，确认填在当前启用配置里 |
| `403 Forbidden` | 先确认 Key 分组和模型名；仍失败时看 [报错与踩坑](/errors/) |
| Base URL 路径错误 | 手动配置只填 `https://api.usegoodai.com/v1`；生成配置不要再补 `/v1` |
| 套用了其它站点模板 | 删除这条配置，重新用自定义供应商填写 UseGoodAI 参数 |

## 进阶理解

CC Switch 只是写配置，不替代 Codex、OpenClaw、Hermes 等客户端。目标客户端启动后才会读取配置并向 UseGoodAI 发起请求；保存配置后没有重启客户端，是最常见的“不生效”原因。
