# Claude Code Desktop 接入第三方 GPT

本页适合希望在 Claude Code Desktop 里接入第三方 GPT / OpenAI-compatible API 的用户。配置完成后，桌面客户端界面仍然是 Claude Code Desktop，但模型请求会使用 UseGoodAI 的 API Key、Base URL 和模型名。

::: tip 最短结论
新增一个自定义 provider，按 OpenAI-compatible 方式填写：Base URL 通常填 `https://api.usegoodai.com/v1`，API Key 填 UseGoodAI 后台复制的 Key，模型名以后台当前分组可用模型为准。
:::

::: warning 不要混用模型名
接第三方 GPT 时，模型名不要填 Claude 模型名。应填写 UseGoodAI 后台当前 API Key 所属分组里实际可用的 GPT / OpenAI-compatible 模型名，例如 `gpt-5.5`。
:::

## 先确认适不适合

| 你的情况 | 是否适合 |
| --- | --- |
| 想在 Claude Code Desktop 里使用第三方 GPT 模型 | 适合 |
| 已有 UseGoodAI API Key 和可用模型 | 适合 |
| 客户端里能看到第三方推理、自定义 provider 或 API 配置入口 | 适合 |
| 想配置终端里的 `claude` 命令 | 不适合，这通常是另一套配置 |
| 想配置 OpenAI Codex CLI / Codex App | 不适合，优先看 [Codex](/clients/codex) |

桌面客户端的第三方推理配置通常只作用于桌面客户端本身，不等于已经配置了终端命令、其它 Agent 工具或 Codex 的 `.codex` 配置。

## 准备项

| 需要 | 用来做什么 |
| --- | --- |
| UseGoodAI API Key | 填入客户端的 API Key / Token 字段 |
| 可用模型名 | 填入客户端的 Model 字段 |
| Claude Code Desktop | 实际发起桌面端请求 |
| 配置入口 | Settings、Developer、Model Provider、API Provider 或 Third-party inference 一类入口 |
| 稳定网络 | 确保客户端能访问 UseGoodAI API 地址 |

如果还没有 API Key，先按 [快速开始](/quick-start) 创建。创建后回到后台确认这个 Key 所属分组支持哪个模型，再把模型名原样填到客户端。

## Base URL 怎么填

普通 OpenAI-compatible 配置里，Base URL 通常填写：

```text
https://api.usegoodai.com/v1
```

不要手动拼成：

```text
https://api.usegoodai.com/v1/chat/completions
https://api.usegoodai.com/v1/responses
```

多数客户端会自己在 Base URL 后面请求 `/chat/completions`、`/models` 等接口。你只需要填写它要求的根地址。

::: warning 按界面要求优先
如果 Claude Code Desktop 当前版本或某个配置工具明确要求填写 HTTPS 域名、根地址或完整接口地址，按它的界面说明填写。不要为了“更完整”手动追加 `/chat/completions` 或 `/responses`。
:::

## 配置步骤

### 1. 打开配置入口

先安装或升级 Claude Code Desktop。安装入口通常是：

```text
https://claude.com/download
```

打开客户端后，进入设置页，查找下面任意一种入口：

| 入口名称 | 说明 |
| --- | --- |
| Developer / Configure third-party inference | 常见的第三方推理入口 |
| API Provider / Model Provider | 常见的自定义服务商入口 |
| Models / Custom Provider | 常见的模型配置入口 |

如果你的版本需要启用 Developer Mode，常见路径是：

1. 打开 **Settings**。
2. 进入 **Help** 或 **Troubleshooting**。
3. 启用 **Developer Mode**。
4. 按提示重启客户端。
5. 回到 **Developer** 或模型配置入口。

不同版本的菜单名称可能略有差异，核心是找到能填写 `Base URL`、`API Key` 和 `Model` 的第三方 API 配置页。

### 2. 添加自定义 provider

在 provider / API 配置页里选择新增，不要套用其它站点的配置模板。没有明确写给 UseGoodAI 的配置入口时，按自定义 provider 配置。

| 字段 | 填写 |
| --- | --- |
| Provider name / 名称 | `UseGoodAI` |
| Provider type / 类型 | `OpenAI`、`OpenAI-compatible` 或 `Custom` |
| Base URL | 通常填 `https://api.usegoodai.com/v1` |
| API Key | 从 UseGoodAI 后台复制的 API Key |
| Model | UseGoodAI 后台当前分组可用的模型名，例如 `gpt-5.5` |

如果界面有模型列表但加载为空，可以先手动添加一个模型名。第一次只填一个确认可用的模型，跑通后再补其它模型。

### 3. 保存并重启

保存配置后，按界面要求点击 **Apply**、**Save** 或 **Apply locally**。

如果客户端提示重启，按提示重启。即使没有提示，也建议彻底退出 Claude Code Desktop 后重新打开一次，避免旧配置还在内存里。

### 4. 切换到新配置

重新打开后，在模型或 provider 选择处确认当前使用的是刚才添加的 `UseGoodAI` provider，并选择你填写的 GPT 模型。

不要选择官方 Claude 模型名来测试第三方 GPT 接入。这里要测试的是 UseGoodAI 后台分组里的模型。

### 5. 发送测试并看后台记录

在 Claude Code Desktop 里发送一句简单测试：

```text
请用一句话回复：Claude Code Desktop 已通过 UseGoodAI 连接成功。
```

然后回到 UseGoodAI 后台查看这个 API Key 是否出现调用记录或用量变化。

| 结果 | 判断 |
| --- | --- |
| 客户端正常回复，后台有调用记录 | 配置成功 |
| 客户端报错，后台没有记录 | 请求没有打到 UseGoodAI，先查配置是否生效 |
| 后台有记录但返回错误 | 请求到了 UseGoodAI，继续查 Key、分组、模型和权限 |

## 切回默认配置

如果需要退出第三方 GPT，回到第三方推理或 provider 配置页，停用、删除或切回默认 provider。切换后建议重启客户端，再确认当前模型选择已经回到你想使用的配置。

## 常见问题

### 后台没有调用记录

通常说明请求没有到达 UseGoodAI。

| 检查项 | 处理 |
| --- | --- |
| 当前 provider | 确认已经切到 `UseGoodAI`，不是旧 provider |
| Base URL | 普通 OpenAI-compatible 配置通常是 `https://api.usegoodai.com/v1` |
| 配置是否保存 | 保存后重启 Claude Code Desktop |
| 代理或网关 | 确认没有把请求转到其它地址 |
| 终端配置 | 桌面端配置不一定影响终端 `claude` 命令 |

### 401 / Unauthorized

优先检查 API Key。

| 可能原因 | 处理 |
| --- | --- |
| Key 复制不完整 | 从 UseGoodAI 后台重新复制 |
| 前后多了空格或换行 | 删除多余字符后保存 |
| Key 已删除或不可用 | 新建或更换一个有效 Key |
| Key 填错位置 | 确认填在 API Key / Token 字段 |

### 403 / Forbidden

403 通常表示 Key 被识别了，但当前分组、模型、额度或权限不允许这次调用。

| 检查项 | 处理 |
| --- | --- |
| Key 所属分组 | 回后台确认这个 Key 能用哪些模型 |
| 模型名 | 换成该分组明确支持的模型 |
| 额度和权限 | 检查余额、套餐、分组权限或后台错误说明 |
| 外接规则 | 如果后台有更具体的拒绝原因，按后台提示处理 |

### 模型列表为空

模型列表为空不一定表示 Key 无效。有些客户端不会自动拉取第三方模型列表，或者只支持手动添加模型。

先手动填写一个 UseGoodAI 后台确认可用的模型名，例如：

```text
gpt-5.5
```

保存后重启客户端，再到模型选择处确认是否出现。

### 模型名不匹配

不要把 Claude 模型名、其它平台教程里的模型名或旧配置里的模型名直接填进来。

正确做法：

1. 回到 UseGoodAI 后台。
2. 找到当前 API Key 所属分组。
3. 复制这个分组里实际可用的模型名。
4. 原样填入 Claude Code Desktop。

大小写、点号、横线和斜杠都要一致。

### 配置保存后没有生效

按这个顺序排查：

| 顺序 | 检查 |
| --- | --- |
| 1 | 是否点击了 Save / Apply / Apply locally |
| 2 | 是否彻底退出并重启客户端 |
| 3 | 当前模型选择是否还停留在旧 provider |
| 4 | 是否有多个配置文件或配置工具覆盖了当前设置 |
| 5 | UseGoodAI 后台是否出现调用记录 |

如果后台一直没有记录，优先按“请求没有到达 UseGoodAI”处理，不要先纠结模型能力。

### 代理、证书或网络问题

如果报 `ETIMEDOUT`、`ENOTFOUND`、`ECONNRESET`、证书错误或连接失败，优先检查本地网络链路。

| 检查项 | 处理 |
| --- | --- |
| 代理 | 临时关闭或更换代理后再试 |
| 公司网络 / 防火墙 | 换网络验证是否被拦截 |
| 证书检查 | 确认没有 HTTPS 检查工具改写证书 |
| 域名拼写 | 确认 Base URL 没有写错 |
| 后台记录 | 没有记录说明请求还没到 UseGoodAI |

## 相关页面

| 页面 | 适合什么时候看 |
| --- | --- |
| [快速开始](/quick-start) | 第一次创建 API Key 并跑通一次 |
| [模型与分组](/models) | 不确定模型名或分组权限 |
| [外接兼容与 Base URL 说明](/external/base-url) | 不确定 `/v1`、兼容模式或完整接口路径 |
| [报错与踩坑](/errors/) | 401、403、连接失败、模型不可用等错误 |
