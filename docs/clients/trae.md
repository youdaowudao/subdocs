# Trae 外接说明

> 适用于在 Trae / Trae 类 AI IDE 中，通过自定义 OpenAI-compatible provider 或 API 配置接入 UseGoodAI 的场景。

Trae 不同版本和不同入口的配置名称可能不完全一样。请以当前界面中能填写 `Base URL`、`API Key`、`Model` 的自定义 provider / API 配置为准。

::: warning
Trae 的内置模型市场、官方账号登录或官方模型入口能用，不等于 UseGoodAI 自定义 API 已经生效。验证时要看当前聊天、编辑器或 Agent 功能是否切到了你创建的自定义 provider。
:::

## 适用场景

- 你在 Trae 或 Trae 类 AI IDE 中看到自定义 OpenAI-compatible provider。
- 客户端允许填写 `Base URL`、`API Key` 和模型名。
- 你想使用 UseGoodAI 后台创建的 API Key 和当前分组里的模型。
- 模型列表自动拉取失败时，客户端仍允许手动添加模型名。

如果当前 Trae 版本只支持官方登录或内置模型市场，没有自定义 API 入口，就不能按本页直接配置。

## 推荐做法

Trae 外接建议按这个顺序配置：

1. 找到 Trae 里的自定义 provider / OpenAI-compatible API 配置。
2. 新增一个 provider，名称可以写 `UseGoodAI`。
3. Base URL 填 `https://api.usegoodai.com/v1`。
4. 填入 UseGoodAI 后台创建的 API Key。
5. 填入或手动添加当前 API Key 分组可用的模型名。
6. 在 Trae 当前使用的聊天、编辑器或 Agent 功能里切换到这个自定义 provider。

::: tip
普通 OpenAI-compatible 手动配置时，Base URL 只填到 `/v1`。客户端会自己拼接 `/models`、`/chat/completions` 等实际接口路径。
:::

## 配置要点

| 项目 | 填写 | 注意 |
| --- | --- | --- |
| Provider 名称 | `UseGoodAI` | 便于在 Trae 的模型选择器里识别 |
| Provider 类型 | `OpenAI` / `OpenAI-compatible` / `Custom` | 以 Trae 当前界面提供的选项为准 |
| Base URL | `https://api.usegoodai.com/v1` | 普通手动配置不要再追加接口路径 |
| API Key | UseGoodAI 后台创建的 Key | 复制完整，不要带多余空格 |
| 模型名 | 以 UseGoodAI 后台当前分组显示为准 | 例如 `gpt-5.5`，实际可用模型以你的后台为准 |
| 模型列表 | 自动拉取失败时手动添加 | 模型列表为空不一定代表不能用 |

不要把下面这些写进普通 Base URL：

```text
https://api.usegoodai.com/v1/models
https://api.usegoodai.com/v1/chat/completions
https://api.usegoodai.com/v1/responses
```

只有 Trae 的某个高级配置项明确要求填写完整接口地址时，才按它的字段说明填写完整路径。普通 `Base URL` 字段不要这样填。

## 配置步骤

### 第一步：新增自定义 provider

在 Trae 设置里找到模型、AI Provider、API Provider 或类似入口，新增一个自定义服务商。

建议填写：

| 字段 | 填写 |
| --- | --- |
| Name / Provider Name | `UseGoodAI` |
| Type / API Type | `OpenAI`、`OpenAI-compatible` 或 `Custom OpenAI` |

如果 Trae 同时有官方模型市场和自定义 API 配置，请进入自定义 API 配置页，不要只在官方模型市场里切模型。

### 第二步：填写 Base URL

普通 OpenAI-compatible 手动配置填写：

```text
https://api.usegoodai.com/v1
```

不要填成 `/v1/models`、`/chat/completions` 或 `/responses`。这些是客户端最终请求时使用的接口路径，通常不应该手动拼进 Base URL。

### 第三步：填写 API Key

在 UseGoodAI 后台创建 API Key，然后复制到 Trae 的 API Key 字段。

格式通常类似：

```text
sk-xxxxxxxx
```

如果 Trae 支持 Header 配置，一般不需要额外填写 `Authorization`。普通 API Key 字段会由客户端自动处理。

### 第四步：填写或添加模型

模型名以 UseGoodAI 后台当前 API Key 所属分组显示为准。

第一次建议只添加一个确定可用的模型，例如：

```text
gpt-5.5
```

如果 Trae 自动拉取模型列表失败、模型列表为空，先不要判定配置失败。只要界面允许手动添加模型，就手动填入后台显示的模型名，再保存测试。

### 第五步：切换当前配置并验证

保存 provider 后，在 Trae 当前使用的聊天、编辑器补全或 Agent 功能里选择这个自定义 provider 和模型。

发送一条简单测试：

```text
请用一句话回复：Trae 已通过 UseGoodAI 连接成功。
```

验证时看三件事：

| 现象 | 说明 |
| --- | --- |
| Trae 正常回复，UseGoodAI 后台有调用记录 | 接入已生效 |
| Trae 正常使用官方模型，但后台没有记录 | 当前功能可能还没切到自定义 provider |
| 后台有记录但报模型错误 | 优先检查模型名和 API Key 分组权限 |

::: warning
不要承诺 Trae 的所有 Agent 能力都能透传到自定义 provider。工具调用、上下文、代码编辑、联网、文件操作等能力，以当前 Trae 版本和自定义 provider 支持情况为准。
:::

## 常见问题

### 改了地址还是连不上

优先检查：

| 检查项 | 正确做法 |
| --- | --- |
| Base URL | 普通手动配置填 `https://api.usegoodai.com/v1` |
| 配置位置 | 确认填在自定义 provider，不是官方模型市场 |
| 当前模型 | 确认聊天或 Agent 当前选择的是 `UseGoodAI` provider |
| 后台记录 | 没有记录时，通常说明请求没有打到 UseGoodAI |

### 401 Unauthorized

| 可能原因 | 处理 |
| --- | --- |
| API Key 少复制、多复制或包含空格 | 从 UseGoodAI 后台重新复制 |
| Key 已删除、过期或无效 | 创建新的 API Key |
| Trae 没有读取到新 Key | 保存后重新选择 provider，必要时重启 Trae |
| 被旧配置覆盖 | 检查环境变量、代理插件或旧 provider 设置 |

### 403 Forbidden / block

先按这个顺序排查：

| 顺序 | 检查项 |
| --- | --- |
| 1 | API Key 是否有效 |
| 2 | 模型是否属于当前 Key 的可用分组 |
| 3 | Base URL 是否只填到 `/v1` |
| 4 | 当前 Trae 功能是否真的切到自定义 provider |
| 5 | 是否经过代理、网关或插件改写了请求头 |

如果前面都正确，仍然返回 `403`，再检查 Trae、系统代理或公司网络是否改写了请求头。更多 Header 排查见 [外接调用 User-Agent 说明](/external/user-agent)。

### 模型不可用 / model not found

| 可能原因 | 处理 |
| --- | --- |
| 模型名拼错 | 回到 UseGoodAI 后台复制完整模型名 |
| 当前 Key 分组不支持该模型 | 换成这个 Key 可用的模型，或更换 Key |
| 照抄了其它教程里的模型名 | 只以 UseGoodAI 后台当前显示为准 |
| Trae 使用了旧模型缓存 | 删除旧模型后重新添加，或重新选择 provider |

### 模型列表为空

模型列表为空不一定是接口不可用。很多客户端会先请求模型列表，但列表拉取失败后仍允许手动配置模型。

处理方式：

1. 确认 Base URL 是 `https://api.usegoodai.com/v1`。
2. 确认 API Key 有效。
3. 在 Trae 的模型管理里手动添加后台显示的模型名。
4. 保存后直接发消息测试。

如果手动添加后仍不能调用，再按 `401`、`403` 和模型不可用继续排查。

### 路径拼错

普通 Base URL 不要写成：

```text
https://api.usegoodai.com/v1/models
https://api.usegoodai.com/v1/chat/completions
https://api.usegoodai.com/v1/responses
```

正确写法是：

```text
https://api.usegoodai.com/v1
```

路径拼错时，常见表现是 `404 Not Found`、`405 Method Not Allowed`、模型列表为空或发送消息失败。

### 网络代理 / 证书问题

如果报网络连接失败、TLS、证书、代理连接错误，优先检查：

| 检查项 | 处理 |
| --- | --- |
| 系统代理 | 临时关闭代理或换一个稳定节点测试 |
| 公司网络 / 网关 | 确认是否拦截 HTTPS 或替换证书 |
| 证书信任 | 如果使用公司证书，确认系统和 Trae 都信任该证书 |
| 代理插件 | 确认没有把请求转到旧地址或其它服务商 |

网络层问题通常不会在 UseGoodAI 后台留下调用记录。如果后台没有记录，先排查 Trae 到 UseGoodAI 的连接链路。

## 相关页面

| 页面 | 什么时候看 |
| --- | --- |
| [外接兼容与 Base URL 说明](/external/base-url) | 不确定 Base URL、`/v1` 或接口路径怎么填 |
| [Responses 与兼容模式说明](/external/compatibility) | 不确定 Trae 当前入口属于哪种协议 |
| [模型与分组](/models) | 不确定 API Key 能调用哪些模型 |
| [外接调用 User-Agent 说明](/external/user-agent) | 遇到 `403 block`，且已经排除 Key、模型和路径问题 |
| [报错与踩坑](/errors/) | 需要继续排查常见报错 |
