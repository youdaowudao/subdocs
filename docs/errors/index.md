# 报错与踩坑

遇到报错时，先判断请求有没有到达 UseGoodAI 后台。

| 后台情况 | 先查什么 |
| --- | --- |
| 没有调用记录 | Base URL、客户端是否保存配置、本地代理、环境变量、旧配置覆盖 |
| 有调用记录 | API Key、模型名、分组权限、额度、后台返回的具体错误 |

不要只看状态码。把客户端完整报错、后台记录里的接口路径和错误信息一起对照，通常能更快定位。

## `401 Unauthorized` / `Incorrect API key provided` / `Invalid API Key`

- 用户看到：`401 Unauthorized`、`Incorrect API key provided`、`Invalid API Key`、`Invalid API Key format`。
- 通常表示：API Key 无效、没被客户端读取，或被旧配置覆盖。
- 先查什么：Key 是否复制完整，前后有没有空格、换行、引号或不可见字符；客户端是否真的读取了最新 Key。
- 怎么处理：重新从后台复制 Key，填到 `API Key` / `Bearer Token` 字段；重启客户端或终端；如果 Key 已删除、禁用或过期，就新建一个 Key。

## `403 Forbidden` / `403 block` / `Permission denied` / `model not allowed`

- 用户看到：`403 Forbidden`、`403 block`、`Permission denied`、`model not allowed`、`not allowed to use this model`。
- 通常表示：请求到了后台，但当前 Key、分组、模型或额度不允许这次调用。
- 先查什么：Key 所属分组是否支持当前模型，模型名是否和后台一致，账号或分组是否有权限和额度。
- 怎么处理：换成该分组可用的模型；把 Key 切到正确分组；补足额度或联系后台处理权限限制。

## `404 Not Found` / `Cannot POST /v1/chat/completions`

- 用户看到：`404 Not Found`、`Cannot POST /v1/chat/completions`、`Cannot POST /v1/responses`、`Not Found`。
- 通常表示：请求路径不对，或客户端把 Base URL 和完整接口路径拼错了。
- 先查什么：Base URL 是否填成了完整接口地址；客户端最终请求的是 `/v1/chat/completions` 还是 `/v1/responses`。
- 怎么处理：普通 OpenAI-compatible 客户端通常填 `https://api.usegoodai.com/v1`；Codex 等 Responses 接入按后台生成配置或对应教程填写，不要手动追加 `/chat/completions` 或 `/responses`。

## `405 Method Not Allowed`

- 用户看到：`405 Method Not Allowed`、`Method Not Allowed`。
- 通常表示：请求方法不对，常见于把 API 地址放进浏览器打开，或客户端用错接口类型。
- 先查什么：客户端是否在用 POST 请求；Base URL 是否填到了客户端要求的位置。
- 怎么处理：不要用浏览器直接测试聊天接口；回到客户端配置页，只填写 Base URL、API Key 和模型名，让客户端自己拼接请求路径。

## `429 Too Many Requests` / `rate limit`

- 用户看到：`429 Too Many Requests`、`rate limit`、`Rate Limit Exceeded`、`insufficient_quota`。
- 通常表示：触发频率限制、并发限制，或额度不足。
- 先查什么：后台额度、当前 Key 或分组限制、是否有多个客户端同时请求。
- 怎么处理：降低并发和重试频率；等待限制窗口恢复；如果提示额度不足，先充值或换可用 Key。

## `500 Internal Server Error`

- 用户看到：`500 Internal Server Error`、`API Error 500`。
- 通常表示：上游或中转侧临时错误，也可能是请求体触发了服务端异常。
- 先查什么：后台记录里的具体错误、同一模型是否连续失败、换一个短输入是否正常。
- 怎么处理：先重试一次；仍失败时换模型或稍后再试；如果只有某段输入失败，缩短上下文后再发。

## `502 Bad Gateway`

- 用户看到：`502 Bad Gateway`、`Bad Gateway`。
- 通常表示：网关到上游服务连接失败或上游返回异常。
- 先查什么：同一时间其它模型是否也失败，后台是否有上游错误说明。
- 怎么处理：稍后重试；临时切换到其它可用模型；如果持续出现，保留后台记录和客户端完整报错再反馈。

## `503 Service Unavailable`

- 用户看到：`503 Service Unavailable`、`Overloaded`、`model_not_found`。
- 通常表示：上游服务过载、模型暂不可用，或该渠道下模型已下线。
- 先查什么：后台记录中的模型名和上游错误；模型是否仍在当前分组可用列表里。
- 怎么处理：换成后台明确可用的模型；等待服务恢复；如果是 `model_not_found`，不要反复重试同一个模型名。

## `504 Gateway Timeout`

- 用户看到：`504 Gateway Timeout`、`gateway timeout`。
- 通常表示：请求已发出，但上游或中转等待响应超时。
- 先查什么：输入是否过长、模型是否响应慢、本地网络是否稳定。
- 怎么处理：缩短上下文或新开会话；降低输出长度；稍后重试或换响应更快的模型。

## `ECONNRESET` / `ETIMEDOUT` / `ENOTFOUND` / `Connection refused`

- 用户看到：`ECONNRESET`、`ETIMEDOUT`、`ENOTFOUND`、`ECONNREFUSED`、`Connection refused`、`API Error (Connection error.)`。
- 通常表示：本地到服务器的网络链路不通，或域名、代理、网关配置有问题。
- 先查什么：后台有没有调用记录；本地代理是否拦截；域名是否写错；公司网络、防火墙或容器网络是否能访问接口域名。
- 怎么处理：确认 Base URL 拼写；关闭或更换代理后重试；Docker / WSL / 远程服务器场景要在实际运行客户端的环境里测试网络。

## `model not found` / `The model does not exist`

- 用户看到：`model not found`、`The model does not exist`、`Invalid model`、`model_not_found`。
- 通常表示：模型名写错，或当前 Key 分组没有这个模型。
- 先查什么：后台模型列表里的准确模型名；Key 所属分组是否包含该模型。
- 怎么处理：复制后台显示的模型名，不要手写猜测；先用一个确定可用的模型跑通，再切换到其它模型。

## `invalid_request_error`

- 用户看到：`invalid_request_error`、`invalid request`、`bad request`。
- 通常表示：请求体不符合当前接口协议，或客户端把 Responses / Chat Completions 模式混用了。
- 先查什么：客户端当前走的是 `/v1/responses` 还是 `/v1/chat/completions`；配置里的协议模式是否和教程一致。
- 怎么处理：Codex 等支持 Responses 的工具优先用 Responses 配置；普通聊天客户端使用 OpenAI-compatible 配置；不要把两个协议的字段混在一起。

## `context_length_exceeded`

- 用户看到：`context_length_exceeded`、`maximum context length`、`This model's maximum context length is`。
- 通常表示：当前对话、文件或输入超过模型上下文上限。
- 先查什么：是否长时间没有新开会话；是否一次性塞入太多文件、日志或网页内容。
- 怎么处理：新开会话或压缩上下文；减少一次性输入；换更大上下文模型前，先确认当前 Key 分组支持该模型。

## JSON / stream / SSE 解析类错误

- 用户看到：`Unexpected token`、`JSON parse error`、`stream error`、`SSE error`、`Invalid event stream`、`Premature close`。
- 通常表示：客户端预期的响应格式和实际返回不一致，或流式响应被网络中断。
- 先查什么：客户端是否选错协议模式；后台记录是否返回了非 JSON 错误页；本地代理是否改写响应。
- 怎么处理：按客户端教程重新选择 Responses 或普通兼容模式；关闭会改写流量的代理；如果非流式可用而流式失败，先关闭 stream 验证基础配置。
