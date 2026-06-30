# JetBrains 外接说明

本页适用于在 JetBrains 系 IDE 或 IDE 插件里接入 OpenAI-compatible / custom provider 的场景，例如 IntelliJ IDEA、PyCharm、WebStorm、GoLand、PhpStorm 等。

不同 JetBrains 插件支持的字段和功能不完全一样。UseGoodAI 侧提供的是 API 接入能力，IDE 里能否自动拉取模型、是否支持工具调用、是否支持某些 JetBrains 官方 AI 功能，以当前插件支持为准。

---

## 适用场景

- IDE 插件要求填写 `Base URL`、`API Key`、`Model`。
- 插件支持 OpenAI-compatible、OpenAI API、custom provider 或自定义服务商。
- 插件会自动拉取模型列表，或允许手动填写模型名。
- 浏览器插件、本地代理或 IDE 插件需要通过 UseGoodAI 发起 OpenAI-compatible 调用。

如果插件只能绑定某个官方账号，不能填写自定义 API 地址，就不属于本页场景。

---

## 推荐接入思路

JetBrains 外接建议按这条路径配置：

1. 先在 UseGoodAI 后台创建 API Key，并确认当前 Key 所属分组可用模型。
2. 在 JetBrains 里安装支持 OpenAI-compatible / custom provider 的插件。
3. 如果插件可以自动拉取模型列表，先让插件读取一次。
4. 如果模型列表为空或读取失败，手动填写后台确认可用的模型名。
5. 保存后发送一句短测试，再回 UseGoodAI 后台查看调用记录。

这样做的好处是：

- 不需要猜接口路径。
- 模型名以后台分组为准，减少 `model not found`。
- 插件能力和 API 可用性可以分开排查。

---

## 配置步骤

### 第一步：准备后台信息

先准备这几项：

| 项目 | 填什么 |
| --- | --- |
| API Key | 从 UseGoodAI 后台创建并复制 |
| Base URL | 普通 OpenAI-compatible 手动配置通常填 `https://api.usegoodai.com/v1` |
| 模型名 | 以当前 API Key 所属分组实际可用模型为准，例如 `gpt-5.5` |
| Provider 类型 | 优先选择 OpenAI-compatible、OpenAI API、custom provider 或自定义服务商 |

::: warning Base URL 不要写完整接口
普通 OpenAI-compatible 手动配置时，Base URL 通常只填：

```text
https://api.usegoodai.com/v1
```

不要填成：

```text
https://api.usegoodai.com/v1/chat/completions
```

也不要填成：

```text
https://api.usegoodai.com/v1/models
```

`/chat/completions` 和 `/models` 是插件实际请求时可能自动拼接的接口路径，不是常规 Base URL。
:::

### 第二步：安装 IDE 插件

在 JetBrains IDE 中打开插件市场，安装你要使用的 AI 插件或 OpenAI-compatible 插件。

常见入口名称可能是：

| 插件入口 | 说明 |
| --- | --- |
| OpenAI-compatible | 通常可以填写 Base URL、API Key 和模型名 |
| OpenAI API | 如果允许自定义 API 地址，可以按本页配置 |
| Custom provider | 适合手动添加 UseGoodAI |
| 自定义服务商 / 自定义接口 | 按字段填写 Base URL、Key、模型 |

如果插件只显示固定服务商、没有自定义 API 地址入口，需要先确认该插件是否支持外接服务。

### 第三步：填写 Base URL 和 API Key

在插件的 provider 或 API 设置里填写：

| 字段 | 填写 |
| --- | --- |
| Name / Provider name | `UseGoodAI` |
| Base URL / API Base / Endpoint | `https://api.usegoodai.com/v1` |
| API Key / Token | UseGoodAI 后台复制的 API Key |
| API 类型 | OpenAI-compatible / Chat Completions，或插件当前支持的自定义 OpenAI 接入 |

如果插件区分 `Base URL` 和完整 `Endpoint`，先按 `Base URL` 填到 `/v1`。只有插件明确要求填写完整接口地址时，才按插件自己的说明处理。

### 第四步：处理模型列表

很多插件会通过 `/models` 自动读取模型列表。实际配置时按下面处理：

| 现象 | 处理 |
| --- | --- |
| 自动出现模型 | 选择后台确认可用的模型测试 |
| 模型列表为空 | 手动填写模型名，不要直接判断 API 不可用 |
| 拉取模型时报错 | 先检查 Key、Base URL 和网络代理；再手动添加模型测试聊天 |
| 聊天时报模型不存在 | 回 UseGoodAI 后台核对模型名和 Key 分组 |

手动填写模型时，建议第一次只填一个后台明确可用的模型。

示例：

```text
gpt-5.5
```

::: tip 模型名要逐字一致
模型名以 UseGoodAI 后台当前分组显示为准，包括大小写、点号、横线和斜杠。不要照抄其它平台教程里的模型名。
:::

### 第五步：注意 IDE 网络环境

JetBrains IDE、浏览器插件或本地代理可能有自己的网络设置。配置失败时，不要先判断 API 不可用，先确认请求有没有到达 UseGoodAI 后台。

常见影响项：

| 影响项 | 检查什么 |
| --- | --- |
| IDE 代理 | JetBrains 的 HTTP Proxy 是否覆盖系统代理 |
| 浏览器插件代理 | 插件是否走了浏览器代理、扩展代理或本地转发 |
| 证书 | 公司网络、自签证书或 HTTPS 检查是否拦截请求 |
| CORS | 浏览器内插件或网页面板是否被跨域策略限制 |
| 本地代理 | `localhost` 网关、反向代理或抓包工具是否改写路径和 Header |

如果后台没有调用记录，优先排查本机网络、插件配置是否保存、代理是否生效、旧配置是否覆盖。

---

## 验证连接

配置完成后，在 JetBrains 插件里选择 UseGoodAI provider 和刚填写的模型，发送一句短测试：

```text
请用一句话回复：JetBrains 已连接 UseGoodAI 成功。
```

然后回到 UseGoodAI 后台查看这个 API Key 是否出现调用记录。

| 结果 | 说明 |
| --- | --- |
| IDE 正常回复，后台有调用记录 | 接入成功 |
| IDE 报错，后台没有调用记录 | 先查 Base URL、插件配置保存、IDE 代理和本地网络 |
| 后台有记录但被拒绝 | 先查 API Key、模型名、分组权限和额度 |
| 模型列表为空但手动模型能聊天 | 模型列表接口或插件解析不影响聊天调用 |

---

## 常见问题

### 401 / Unauthorized

| 可能原因 | 处理 |
| --- | --- |
| API Key 复制不完整 | 从 UseGoodAI 后台重新复制 |
| Key 已删除、禁用或过期 | 换一个有效 Key |
| Key 填到了错误 provider | 确认当前插件正在使用 `UseGoodAI` provider |
| IDE 读取了旧配置 | 保存后重启 IDE，或删除插件里的旧 Key |

### 403 / Forbidden / block

| 可能原因 | 处理 |
| --- | --- |
| 当前 Key 分组不支持该模型 | 换成后台分组里可用的模型 |
| 模型名拼错 | 复制后台显示的模型名 |
| 分组、额度或外接规则限制 | 查看后台记录里的具体错误 |
| 代理或插件改写了请求头 | 先确认 Key、Base URL、模型都正确，再检查 Header |

403 通常表示请求已经到达后台，但当前 Key、模型、分组或调用规则不允许这次请求。

### 模型列表为空

模型列表为空不一定代表不能聊天。先按下面顺序处理：

1. 确认 Base URL 是 `https://api.usegoodai.com/v1`。
2. 确认 API Key 来自 UseGoodAI 后台。
3. 在插件里手动添加一个后台可用模型。
4. 保存后直接发送测试消息。

如果聊天能正常回复，可以继续使用手动模型列表。

### 路径错误 / Not Found / Cannot POST

| 检查项 | 正确写法 |
| --- | --- |
| Base URL | `https://api.usegoodai.com/v1` |
| 不要填写 | `https://api.usegoodai.com/v1/chat/completions` |
| 也不要填写 | `https://api.usegoodai.com/v1/models` |

多数 JetBrains 插件会自己拼接 `/chat/completions` 或 `/models`。把完整接口写进 Base URL，反而容易变成重复路径或错误路径。

### 连接超时 / Connection timeout

连接超时通常先看本地到接口域名的网络链路：

| 检查项 | 处理 |
| --- | --- |
| IDE 代理 | 打开 JetBrains HTTP Proxy 设置，确认代理是否正确 |
| 系统代理 | 临时关闭或更换代理后重试 |
| 公司网络 / 防火墙 | 换网络或热点验证 |
| 证书拦截 | 检查是否有 HTTPS 检查、自签证书或抓包工具 |
| 本地代理 | 确认本地网关没有把 `/v1`、Header 或请求体改坏 |

如果 UseGoodAI 后台没有调用记录，说明请求大概率还没有到达 UseGoodAI。

### 本机浏览器可用，但 IDE 插件不可用

这通常说明问题在 IDE 插件或 IDE 网络环境里。优先检查：

- JetBrains HTTP Proxy 是否和浏览器代理不同。
- 插件是否保存并启用了 UseGoodAI provider。
- 插件是否读取了旧 Key 或旧模型。
- 插件是否要求手动添加模型，而不是只依赖模型列表。
- 本地代理、证书或浏览器扩展是否只对浏览器生效，没有覆盖 IDE。

---

## 相关页面

| 页面 | 用途 |
| --- | --- |
| [外接兼容与 Base URL 说明](/external/base-url) | 不确定 Base URL、协议或 `/v1` 应该怎么填 |
| [Responses 与兼容模式说明](/external/compatibility) | 不确定当前插件应该走 Responses 还是普通 OpenAI-compatible |
| [外接调用 User-Agent 说明](/external/user-agent) | 怀疑代理、插件或 Header 影响外接识别 |
| [报错与踩坑](/errors/) | 按状态码排查 401、403、路径错误和连接失败 |
