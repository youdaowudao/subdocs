# Codex 内置生图

ChatGPT 桌面应用中的 Codex 保留 ChatGPT 登录状态时，可以继续使用内置的 `image_gen` 工具。单独把模型接口改成 OpenAI-compatible，只能让普通对话、代码任务、文件修改走 UseGoodAI，不能自动给当前会话增加内置生图工具。

看到下面报错时，含义是当前会话没有拿到内置 `image_gen` 工具，不代表 API Key 填错，也不代表模型不能画图。

```text
错误：当前会话没有可用的内置 image_gen 工具，因此无法生成图片
```

需要内置生图时，先按目标选择入口。

## 按目标选择入口

| 目标 | 入口 | 说明 |
| --- | --- | --- |
| 快速生成几张图片 | 用 [无限画布](/images/infinite-canvas) | 适合临时出图、调提示词、多轮看效果，不需要折腾 Codex 内置工具。 |
| 用图片生成 API | 看 [图片生成 API](/images/image-generation) | 适合自己写脚本、服务端接口、批量任务或接入已有业务系统。 |
| 继续用 Codex 内置 `image_gen` | 看 [保持 ChatGPT 登录同时连接中转站](/chatgpt-login-usegoodai) | 保留 ChatGPT 登录状态，在配置里开启 `image_generation`，再把模型请求指到 UseGoodAI。 |

## 内置生图什么时候用

需要同时满足下面需求时，使用内置生图配置：

- 保留 ChatGPT 登录状态。
- 继续使用 ChatGPT 桌面应用中 Codex 的内置工具和插件入口。
- 使用手机连接、远程办公或其他账号连接。
- 让模型请求走 UseGoodAI。

按 [保持 ChatGPT 登录同时连接中转站](/chatgpt-login-usegoodai) 配好后，再回到 ChatGPT 桌面应用中的 Codex 测试内置生图。

看到当前会话没有 `image_gen` 工具时，先确认已经保持 ChatGPT 登录，并在配置里开启 `image_generation`。
