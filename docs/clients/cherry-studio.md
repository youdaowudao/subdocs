# Cherry Studio 接入

Cherry Studio 是桌面端聊天客户端，适合想快速用图形界面接入 UseGoodAI 的个人用户。

::: tip 最短结论
在 Cherry Studio 里新增一个 **自定义服务商**，服务商类型选 **OpenAI**，API 地址填 `https://api.usegoodai.com/v1`，再添加 UseGoodAI 后台分组里可用的模型名。
:::

## 适合谁

| 你的情况 | 是否适合 |
| --- | --- |
| 想下载一个桌面客户端直接聊天 | 适合 |
| 使用 Windows / macOS / Linux | 适合 |
| 想自己控制常用模型列表 | 适合 |
| 想多人共享一个网页聊天入口 | 不适合，优先看 Open WebUI 或 LibreChat |
| 想配置 Codex / Agent 工具调用链路 | 不适合，优先看 Codex 或对应 Agent 页面 |

## 准备信息

| 项目 | 填什么 |
| --- | --- |
| 服务商名称 | `UseGoodAI` |
| 服务商类型 | `OpenAI` |
| API Key | 从 UseGoodAI 后台复制 |
| API 地址 / Base URL | `https://api.usegoodai.com/v1` |
| 模型名 | 以后台分组实际可用模型为准，例如 `gpt-5.5` |

::: warning 不要把接口路径填进 Base URL
Cherry Studio 会按 OpenAI-compatible / Chat Completions 兼容方式请求接口。Base URL 只填：

```text
https://api.usegoodai.com/v1
```

不要再加 `/chat/completions`，也不要按 Responses API 去配置普通聊天接入。
:::

## 安装 Cherry Studio

打开 Cherry Studio 官方下载页：

```text
https://www.cherry-ai.com/download
```

| 系统 | 安装方式 |
| --- | --- |
| Windows | 下载 x64 或 ARM64 安装版；如果安装时提示 Visual C++ 运行库，按提示安装 |
| macOS | 按 Mac 芯片选择 Intel 或 Apple Silicon 版本，下载后拖入 Applications |
| Linux | 按页面提供的 x86_64 或 ARM64 包安装 |

安装完成后打开 Cherry Studio，再继续配置。

## 配置 UseGoodAI

### 1. 进入模型服务

在 Cherry Studio 左侧点击 **Settings / 设置**，进入：

```text
Model Services / 模型服务
```

点击服务商列表下方的 **+ Add / 添加**。

### 2. 添加自定义服务商

在弹出的添加窗口里填写：

| 字段 | 填写 |
| --- | --- |
| Provider name / 服务商名称 | `UseGoodAI` |
| Provider type / 服务商类型 | `OpenAI` |

保存后，回到模型服务列表，找到刚添加的 `UseGoodAI`。

::: info 为什么选 OpenAI
Cherry Studio 的自定义服务商支持 OpenAI、Gemini、Anthropic、Azure OpenAI 等类型。UseGoodAI 在 Cherry Studio 里按普通 OpenAI-compatible 聊天客户端接入，所以这里选 `OpenAI`。
:::

### 3. 填写 Key 和地址

在 `UseGoodAI` 服务商配置里填写：

| 字段 | 填写 |
| --- | --- |
| API Key | 从 UseGoodAI 后台复制的 API Key |
| API address / API 地址 | `https://api.usegoodai.com/v1` |
| Enable / 启用 | 打开 |

如果界面右侧有 **Check / 检查** 按钮，可以点击一次。检查通过说明 Key 和地址基本可用；如果检查失败，先继续看下面的模型添加和常见错误。

### 4. 添加模型

Cherry Studio 自定义服务商可以手动管理模型。第一次接入建议只添加一个确认可用的模型。

操作步骤：

1. 在 `UseGoodAI` 服务商里找到 **Model management / 模型管理**。
2. 点击 **+ Add / 添加**。
3. 填入 UseGoodAI 后台分组里实际可用的模型名。
4. 保存，并确认 `UseGoodAI` 服务商处于启用状态。

示例：

```text
gpt-5.5
```

::: warning 模型名必须逐字一致
模型名不是 Cherry Studio 随便展示出来就一定能用。以 UseGoodAI 后台当前 API Key 所属分组里实际可用的模型为准，包括大小写、点号、横线和斜杠。
:::

## 验证连接

回到 Cherry Studio 聊天界面：

1. 在模型选择器里选择 `UseGoodAI`。
2. 选择刚刚添加的模型。
3. 发送测试消息：

```text
请用一句话回复：Cherry Studio 已连接成功
```

能正常回复，就说明 Cherry Studio 到 UseGoodAI 的普通聊天链路已经通了。

## 常见错误

### 401 / Unauthorized

| 可能原因 | 处理 |
| --- | --- |
| API Key 少复制或多复制了空格 | 从 UseGoodAI 后台重新复制 |
| Key 已删除、过期或不属于当前账号 | 换一个有效 Key |
| Key 填到了错误位置 | 确认填在 API Key 字段，不是模型名或服务商名称 |

### 404 / 路径错误 / Not Found

| 检查项 | 正确写法 |
| --- | --- |
| Base URL | `https://api.usegoodai.com/v1` |
| 不要填写 | `https://api.usegoodai.com/v1/chat/completions` |
| 接入模式 | OpenAI-compatible / Chat Completions 兼容路径 |

Cherry Studio 会自己拼接最终聊天接口路径，手动加 `/chat/completions` 反而容易导致路径错误。

### 模型不存在

| 可能原因 | 处理 |
| --- | --- |
| 模型名拼错 | 回到 UseGoodAI 后台复制实际模型名 |
| 当前 Key 所属分组不支持该模型 | 换成这个分组可用的模型，或更换 API Key |
| 照抄了其它平台教程里的模型名 | 不照抄外部示例，只看 UseGoodAI 后台 |

### 模型列表没有自动出现

这不一定是故障。直接在 Cherry Studio 的模型管理里手动添加模型 ID 即可。

第一次只添加一个模型，确认聊天成功后，再按需补充其它常用模型。

### 403 / Forbidden / block

先按这个顺序排查：

| 顺序 | 检查项 |
| --- | --- |
| 1 | API Key 是否有效 |
| 2 | Base URL 是否只填到 `/v1` |
| 3 | 模型名是否属于当前分组 |
| 4 | Cherry Studio 是否启用了 `UseGoodAI` 服务商 |
| 5 | 是否经过代理、网关或插件改写了请求头 |

普通 Cherry Studio 接入通常不需要手动修改 `User-Agent`。只有后台请求记录提示客户端识别异常，或你中间加了代理、网关时，再检查最终发到 UseGoodAI 的请求头。

## 下一步排查

| 现象 | 去看 |
| --- | --- |
| 不确定该走 Responses 还是兼容模式 | [Responses 与兼容模式说明](/external/compatibility) |
| 怀疑请求头或代理改写 | [User-Agent 说明](/external/user-agent) |
| 想用网页聊天面板 | [Open WebUI](/clients/open-webui) |
| 已经在自托管 LibreChat | [LibreChat](/clients/librechat) |
