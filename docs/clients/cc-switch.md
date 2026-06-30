# CC Switch 统一配置

CC Switch 是一个桌面配置管理工具，用来统一管理 Codex、Gemini CLI、OpenClaw、Hermes 等 Agent / CLI 客户端的供应商配置。它本身不提供模型，也不会替代 UseGoodAI；真正发起请求的仍然是你正在使用的客户端。

接入 UseGoodAI 时，把 CC Switch 当成“配置写入和切换工具”即可：API Key、模型名和接口地址以 UseGoodAI 后台和目标客户端教程为准。

::: tip UseGoodAI 接入原则
| 配置项 | 怎么填 |
| --- | --- |
| API Key | 从 UseGoodAI 后台 **API 密钥** 页面复制 |
| Model | 以这个 Key 所属分组里实际可用模型为准，例如 `gpt-5.5` |
| Base URL | 后台或配置工具已生成内容时直接使用生成结果；只有普通 OpenAI-compatible 手动配置时，才填 `https://api.usegoodai.com/v1` |
:::

## 先看你是哪种情况

| 你的情况 | 建议 |
| --- | --- |
| 同时使用 Codex、OpenClaw、Hermes 等多个工具 | 适合用 CC Switch 统一管理 |
| 只想把 Codex 先跑通一次 | 先看 [快速开始](/quick-start)，直接复制后台生成的 Codex 配置 |
| 目标客户端已经有 UseGoodAI 后台生成配置 | 优先用后台生成内容，不要额外手改路径 |
| CC Switch 或目标客户端里没有明确的 UseGoodAI 配置 | 按目标客户端的手动配置方式填写 |

::: warning 不要套用其它站点配置模板
CC Switch 里如果出现其它站点的配置模板，不要拿来接 UseGoodAI。不同站点的 Base URL、模型名、协议和外接规则可能不同；没有明确写给 UseGoodAI 的配置，就按自定义供应商或目标客户端手动配置。
:::

## 安装

CC Switch 官方项目地址：<https://github.com/farion1231/cc-switch>

| 系统 | 推荐安装方式 |
| --- | --- |
| Windows | 到 GitHub Releases 下载 `Windows.msi` 安装包或 `Windows-Portable.zip` 便携版 |
| macOS | 使用 Homebrew，或从 Releases 下载 `.dmg` |
| Arch Linux | 使用 AUR 包 `cc-switch-bin` |
| 其它 Linux | 到 Releases 下载 `.deb`、`.rpm` 或 `.AppImage` |

### Windows

打开 CC Switch 的 [Releases](https://github.com/farion1231/cc-switch/releases) 页面，下载最新版本的 Windows 安装包或便携版。

### macOS

如果你已经安装 Homebrew，运行：

```bash
brew install --cask cc-switch
```

也可以到 [Releases](https://github.com/farion1231/cc-switch/releases) 下载 `.dmg` 安装包。

### Arch Linux

```bash
paru -S cc-switch-bin
```

### 其它 Linux

从 [Releases](https://github.com/farion1231/cc-switch/releases) 下载适合当前发行版的安装包：

| 包 | 适合 |
| --- | --- |
| `.deb` | Debian / Ubuntu |
| `.rpm` | Fedora / RHEL / openSUSE |
| `.AppImage` | 不想安装到系统、只想直接运行 |

## 配置 UseGoodAI

下面按通用流程写。不同版本的 CC Switch 界面文案可能略有差异，核心是：选择目标客户端，新增一个供应商配置，把 UseGoodAI 的 Key、模型和接口填进去。

### 1. 在 UseGoodAI 创建 API Key

进入 UseGoodAI 后台的 **API 密钥** 页面，创建一个给目标客户端使用的 Key。

创建后确认三件事：

| 项目 | 为什么要确认 |
| --- | --- |
| Key | 后面要复制到 CC Switch |
| 分组 | 决定这个 Key 能调用哪些模型 |
| 模型名 | 要和客户端里填写的 `model` 一致 |

### 2. 在 CC Switch 添加配置

打开 CC Switch，点击 **添加配置** 或 **添加供应商**，先选择你要管理的目标客户端。

| 目标客户端 | 在 CC Switch 里怎么理解 |
| --- | --- |
| Codex | 管理 Codex 的供应商/API 配置 |
| OpenClaw | 管理 OpenClaw 的 provider 配置 |
| Hermes | 管理 Hermes Agent 的模型供应商配置 |
| 其它支持工具 | 按 CC Switch 当前支持列表选择对应工具 |

如果列表里没有明确适用于 UseGoodAI 的配置入口，不要选择其它站点配置模板。选择自定义供应商、自定义 endpoint，或按目标客户端的手动配置方式填写。

### 3. 填写 UseGoodAI 参数

| 字段 | 填写方式 |
| --- | --- |
| Provider / 供应商名称 | 可写 `UseGoodAI`，只是方便自己识别 |
| API Key | 粘贴 UseGoodAI 后台复制的 Key |
| Model | 填后台分组里实际可用的模型，例如 `gpt-5.5` |
| Base URL | 见下方 `/v1` 规则 |

#### `/v1` 怎么填

| 场景 | 怎么处理 |
| --- | --- |
| UseGoodAI 后台已经生成 Codex 等专用配置 | 直接复制生成结果，不要自己额外补 `/v1` |
| CC Switch 或目标客户端已经生成配置内容 | 使用生成内容，不要再手动拼路径 |
| 普通 OpenAI-compatible 自定义配置 | Base URL 填 `https://api.usegoodai.com/v1` |
| 客户端要求完整请求路径 | 先看该客户端文档，不要把 `/chat/completions` 手动加到 Base URL 后面 |

::: tip
`/v1` 只用于普通 OpenAI-compatible 手动配置。已经由后台或工具生成的配置，以生成结果为准。
:::

### 4. 启用配置并重启客户端

保存后，在 CC Switch 里启用刚才创建的配置。

| 客户端类型 | 生效方式 |
| --- | --- |
| CLI 工具 | 关闭并重新打开终端，再启动客户端 |
| 桌面客户端 | 彻底退出客户端后重新打开 |
| 后台常驻进程 | 重启对应进程或网关 |

很多 CLI 只在启动时读取配置。保存后不重启，是“看起来配置没生效”的常见原因。

## 验证

打开被 CC Switch 管理的目标客户端，先发一个低成本测试：

```text
用一句话回复：当前客户端已经通过 UseGoodAI 连接成功。
```

然后回到 UseGoodAI 后台查看调用记录。

| 现象 | 判断 |
| --- | --- |
| 客户端正常回复，后台有调用记录 | 配置成功 |
| 客户端报错，后台没有记录 | CC Switch 配置没有应用到目标客户端，或客户端读的是旧配置 |
| 后台有记录但模型报错 | 模型名和 API Key 分组不匹配 |
| 后台有记录但被拒绝 | 检查分组权限、模型权限或外接调用规则 |

## 常见错误

### 把 CC Switch 当成模型服务

CC Switch 不是模型服务。它只负责管理和写入配置；模型调用仍然由 Codex、OpenClaw、Hermes 等客户端发起，UseGoodAI 负责提供 API Key、接口和模型能力。

### 套用了其它站点配置模板

不要这样做。其它站点配置模板可能写入不同的 Base URL、模型名、协议或 User-Agent 规则。

接 UseGoodAI 时按下面顺序选：

| 优先级 | 做法 |
| --- | --- |
| 1 | UseGoodAI 后台或目标客户端教程已经给出配置，就用它 |
| 2 | CC Switch 里有明确写给 UseGoodAI 的配置，才使用 |
| 3 | 没有明确配置时，按自定义 OpenAI-compatible 或目标客户端手动配置 |

### Base URL 多加了 `/v1`

如果你是手动填普通 OpenAI-compatible Base URL，可以使用：

```text
https://api.usegoodai.com/v1
```

如果后台或配置工具已经生成内容，不要在生成结果后面再补 `/v1`。重复拼接路径会导致请求地址错误。

### 填了模型名但模型不可用

模型名不是随便填的。优先回到 UseGoodAI 后台确认这个 API Key 所属分组是否支持你填写的模型。

| 检查项 | 说明 |
| --- | --- |
| Key 所属分组 | 决定可用模型范围 |
| Model 字段 | 必须填该分组支持的模型 |
| 客户端配置 | 不要残留旧 provider 的模型名 |

### 401 / Unauthorized

优先检查 API Key：

| 检查项 | 说明 |
| --- | --- |
| 是否复制完整 | 不要多空格、换行或少字符 |
| 是否填到当前启用配置里 | 不要只改了未启用的 provider |
| 是否重启客户端 | 旧终端可能还在读旧配置 |

### 403 / Forbidden

403 通常和权限、分组、模型或外接调用规则有关。

| 检查项 | 说明 |
| --- | --- |
| 分组 | 当前 Key 是否支持目标模型 |
| 模型名 | 是否和后台显示一致 |
| 外接规则 | 目标客户端是否需要额外配置 User-Agent 或其它字段 |
| 后台记录 | 有记录说明请求到了 UseGoodAI，再看具体拒绝原因 |

### 保存后还是没生效

按这个顺序排查：

| 顺序 | 检查 |
| --- | --- |
| 1 | CC Switch 当前启用的是不是刚才创建的配置 |
| 2 | 目标客户端是否已经重启 |
| 3 | 客户端实际读取的是 Windows、WSL 还是 Linux/macOS 的配置目录 |
| 4 | 旧环境变量是否覆盖了 CC Switch 写入的配置 |
| 5 | UseGoodAI 后台是否出现调用记录 |

## 相关页面

| 页面 | 适合什么时候看 |
| --- | --- |
| [快速开始](/quick-start) | 第一次把 Codex 接入 UseGoodAI |
| [Codex](/clients/codex) | Codex 配置目录、Windows / WSL 路径和常见报错 |
| [OpenClaw](/clients/openclaw) | OpenClaw 自定义 provider 配置 |
| [Hermes Agent](/clients/hermes) | Hermes provider、协议选择和验证 |
| [报错与踩坑](/errors/) | 请求到了后台但被拒绝 |

## 参考资料

- CC Switch 官方项目：<https://github.com/farion1231/cc-switch>
- CC Switch Releases：<https://github.com/farion1231/cc-switch/releases>
