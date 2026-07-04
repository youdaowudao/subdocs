# Codex 直接生图配置说明

截至当前 Codex `0.142`，按普通 API 方式接入 UseGoodAI 后，普通对话、代码任务、文件修改通常可以正常使用；但让 Codex 直接生成图片时，会看到类似报错：

```text
错误：当前会话没有可用的内置 image_gen 工具，因此无法生成图片
```

这个报错不是 API Key 填错，也不是模型不能画图。它的核心含义是：当前 Codex 会话没有拿到内置 `image_gen` 工具。

所以，Codex 生图要按目标选方案：

| 目标 | 推荐方式 | 说明 |
| --- | --- | --- |
| 快速生成几张图片 | 用 [无限画布](/images/infinite-canvas) | 适合临时出图、调提示词、多轮看效果，不需要折腾 Codex 内置工具。 |
| 用图片生成 API | 看 [图片生成 API](/images/image-generation) | 适合自己写脚本、服务端接口、批量任务或接入已有业务系统。 |
| 让 Codex 在工作流里调用生图 | 接生图 MCP 工具，或写一个小插件 | 把 UseGoodAI 生图接口封成工具，让 Codex 明确调用、保存结果、继续处理文件。 |
| 继续用 Codex App 内置 `image_gen` | 用本文方法 | 先让 Codex App 保持 ChatGPT 登录态，在配置里开启 `image_generation`，再把模型 provider 指到 UseGoodAI；这样保留插件、内置工具和手机端远程使用能力，同时让后台模型请求走第三方 API。 |

本文只讲最后一种：保留 Codex App 登录态，同时让模型请求走 UseGoodAI。

## 懒人方法：复制给 AI 帮你改

把下面这段话复制给能操作本机文件的 AI。用户只需要最后把 `experimental_bearer_token` 双引号里的内容换成自己的API Key。

```text
请帮我修改 Windows Codex配置，一般是在：
C:\Users\我的用户名\.codex\config.toml

要求：
1. 先备份旧 config.toml。
2. 删除旧的模型端点配置：model_provider、[model_providers.xxx]、base_url。
3. 保留 MCP、插件、项目权限、workspace trust 等无关配置。
4. 把下面配置放到文件开头；如已有 [features]，合并进去，不要写两个。
5. 改完提醒我只替换 experimental_bearer_token 里的 API Key。

model_provider = "UseGoodAI"
model = "gpt-5.5"
review_model = "gpt-5.5"
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.UseGoodAI]
name = "UseGoodAI"
base_url = "https://api.usegoodai.com/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "这里完整填写你的中转站key"

[features]
image_generation = true
```

## 手动配置过程

想手动修改，可以按下面顺序来：

1. 打开 Codex App，正常登录 ChatGPT。
2. 打开 `C:\Users\你的用户名\.codex\config.toml`；没有就新建。
3. 修改前先复制一份旧的 `config.toml` 作为备份。
4. 删除旧的模型端点配置，只保留下面这段 `[model_providers.UseGoodAI]`。
5. 保留文件下方已有的 MCP、插件、项目权限、工作区等其它配置。
6. 把下面这段配置放到文件开头，只改 `experimental_bearer_token` 里的 API Key。如果原来已经有 `[features]`，把 `image_generation = true` 合并进去，不要重复创建第二个 `[features]`。
7. 保存文件。
8. 完全退出 Codex App；不要只关窗口，必要时从托盘或任务管理器结束进程。
9. 重新打开 Codex App，直接输入“生成一张苹果图片”进行测试。

```toml
model_provider = "UseGoodAI"
model = "gpt-5.5"
review_model = "gpt-5.5"
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.UseGoodAI]
name = "UseGoodAI"
base_url = "https://api.usegoodai.com/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "这里完整填写你的中转站key"

[features]
image_generation = true
```

## 常见问题

| 问题 | 处理方式 |
| --- | --- |
| 修改配置后没有生效 | 保存配置后完全退出 Codex App，再重新打开。 |
| 配置后 Codex 打不开或无法运行 | 检查 `config.toml` 里是不是写了两个 `[features]`。如果有，合并成一个。 |
| 能写代码，但不能生图 | 检查 `[features]` 里有没有写 `image_generation = true`。 |
| 之前配置过环境变量 | 先删掉，避免它干扰本次测试。 |
| 配置里残留 `[model_providers.OpenAI]` | 删除旧的自定义 OpenAI provider，统一使用 `[model_providers.UseGoodAI]`。 |
| 请求没有到达 UseGoodAI | 检查 `base_url` 是否为 `https://api.usegoodai.com/v1`，API Key 是否复制完整。 |
| provider 不生效 | 确认 `model_provider = "UseGoodAI"` 和 `[model_providers.UseGoodAI]` 完全一致。 |

一句话总结：直连第三方 API 只能解决编程模型请求；要让 Codex 稳定调用外部生图能力，用 MCP 或插件；如果一定要用 Codex App 内置生图，就先登录 ChatGPT，再按本页配置自定义端点。
