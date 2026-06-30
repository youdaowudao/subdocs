# Open WebUI 接入 UseGoodAI

Open WebUI 是自建网页聊天界面。把 UseGoodAI 接进去时，按 **OpenAI-compatible / Chat Completions** 方式配置即可。

::: tip 最短配置
在 Open WebUI 管理后台新增 OpenAI-compatible 连接：

| 字段 | 填写 |
| --- | --- |
| URL / Base URL | `https://api.usegoodai.com/v1` |
| API Key | UseGoodAI 后台创建的 API Key |
| Model IDs (Filter) | 先填 1 个后台确认可用的模型，例如 `gpt-5.5` |

不要在 Base URL 后面再追加 `/chat/completions`。
:::

## 适合谁

| 你的情况 | 是否适合 |
| --- | --- |
| 想用浏览器聊天 | 适合 |
| 已经有 Open WebUI 实例 | 适合 |
| 想给自己或小团队提供统一聊天入口 | 适合 |
| 不想自建服务、碰 Docker 或管理员设置 | 不适合 |
| 只想装一个本地桌面客户端马上用 | 不适合 |

## 需要准备

| 项目 | 说明 |
| --- | --- |
| Open WebUI | 已安装，且能进入管理员后台 |
| 管理员账号 | 需要能打开 Admin Settings / Connections |
| UseGoodAI API Key | 在 UseGoodAI 后台创建并复制 |
| 可用模型名 | 以 API Key 所属分组实际可用模型为准 |
| Base URL | 固定填 `https://api.usegoodai.com/v1` |

::: warning 不要猜模型名
模型是否可用取决于 UseGoodAI 后台分组和权限。先用后台确认可用的 1 个模型跑通，再增加其它模型。
:::

## 1. 安装并运行 Open WebUI

如果你已经有可用的 Open WebUI，可以跳过本节。

官方 Docker 最小启动方式：

```bash
docker run -d -p 3000:8080 -v open-webui:/app/backend/data \
  -e WEBUI_SECRET_KEY="请换成一串随机密钥" \
  --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

启动后打开：

```text
http://localhost:3000
```

第一次进入时创建账号。通常第一个注册的账号会成为管理员。

::: tip 生成 `WEBUI_SECRET_KEY`
可以用 `openssl rand -hex 32` 生成一串随机值。没有固定的 `WEBUI_SECRET_KEY`，容器重建后可能导致登录状态失效。
:::

## 2. 选择一种配置方式

Open WebUI 可以用管理后台配置，也可以用环境变量预置。新手建议只选一种。

| 方式 | 适合场景 | 本页建议 |
| --- | --- | --- |
| 管理后台 | 已经能打开 Open WebUI 页面 | 推荐 |
| 环境变量 | 你在维护 Docker / Compose 部署脚本 | 可选 |

不要一边在后台保存连接，一边又在 Docker 环境变量里写另一套 URL 和 Key。两套配置混用时，排错会变得很难。

## 3. 用管理后台添加连接

进入：

```text
Admin Settings -> Connections
```

在 OpenAI / OpenAI API 区域新增一个连接，按下面填写：

| 字段 | 填写 |
| --- | --- |
| Name / 名称 | `UseGoodAI` |
| URL / Base URL | `https://api.usegoodai.com/v1` |
| API Key | UseGoodAI 后台复制的 API Key |
| Model IDs (Filter) | 后台分组里实际可用的模型名 |

保存前检查三点：

| 检查项 | 正确写法 |
| --- | --- |
| URL 带 `/v1` | `https://api.usegoodai.com/v1` |
| URL 不带完整接口路径 | 不要加 `/chat/completions` |
| 接入协议 | 普通 OpenAI-compatible / Chat Completions |

::: warning 本页不是 Responses 接入
Open WebUI 确实支持 Open Responses，但普通 UseGoodAI 聊天接入按 OpenAI-compatible / Chat Completions 配置。除非你明确知道当前入口要走 Responses，否则不要在 Open WebUI 里改成 Responses 路径。
:::

## 4. 模型怎么填

Open WebUI 会尝试通过 `/models` 自动读取模型列表。实际接入时按下面处理：

| 现象 | 处理 |
| --- | --- |
| 自动出现模型 | 直接选择模型测试 |
| 模型太多 | 用 `Model IDs (Filter)` 只保留常用模型 |
| 模型列表拉取失败 | 在 `Model IDs (Filter)` 手动添加模型 |
| 聊天时报模型不存在 | 回 UseGoodAI 后台核对分组和模型名 |

手动添加模型时：

1. 找到 `Model IDs (Filter)`。
2. 输入后台确认可用的模型 ID。
3. 点击 `+` 添加。
4. 保存连接。

示例：

```text
gpt-5.5
```

::: tip 模型列表失败不一定代表不能聊天
Open WebUI 官方也说明，部分 OpenAI-compatible provider 的 `/models` 可能不可用或返回异常。这种情况下手动添加模型即可继续使用 Chat Completions。
:::

## 5. 可选：用环境变量配置

如果你更想在 Docker / Compose 里预置 UseGoodAI，可以用环境变量。使用这种方式时，就不要再在管理后台手动维护另一套连接。

```bash
docker run -d -p 3000:8080 -v open-webui:/app/backend/data \
  -e WEBUI_SECRET_KEY="请换成一串随机密钥" \
  -e OPENAI_API_BASE_URL="https://api.usegoodai.com/v1" \
  -e OPENAI_API_KEY="sk-从UseGoodAI后台复制的APIKey" \
  --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

如果你已经用上面的 Docker 命令创建过同名容器，需要先停掉旧容器，再用新环境变量重新创建。不要删除数据卷，除非你明确想清空 Open WebUI 数据。

```bash
docker stop open-webui
docker rm open-webui
```

然后再运行带环境变量的新命令。

## 6. 验证

回到 Open WebUI 聊天页面：

1. 打开模型选择器。
2. 选择 UseGoodAI 连接下的模型。
3. 发送测试消息：

```text
请用一句话回复：Open WebUI 已连接 UseGoodAI 成功。
```

再回到 UseGoodAI 后台查看这个 API Key 是否出现调用记录。

| 结果 | 说明 |
| --- | --- |
| 页面正常回复，后台有调用记录 | 接入成功 |
| 页面报错，后台没有调用记录 | URL、Key 保存或 Open WebUI 网络连接有问题 |
| 后台有调用记录但模型报错 | 模型名或 Key 分组权限不匹配 |

## 常见问题

### Base URL 要不要加 `/chat/completions`？

不要。Open WebUI 的连接里只填：

```text
https://api.usegoodai.com/v1
```

`/chat/completions` 是 Open WebUI 发起聊天时自动拼接的接口路径，不是用户手动填写的 Base URL。

### 要不要使用 Responses？

普通 Open WebUI 聊天接入不要按 Responses 写。这里使用 OpenAI-compatible / Chat Completions 兼容路径。

只有在 Open WebUI 和当前 UseGoodAI 入口都明确要求 Responses，并且你知道自己要配置什么时，才单独按 Responses 文档处理。

### 连接验证失败，但模型已经手动添加了，还能用吗？

可以继续测试聊天。连接验证常见依赖 `/models`，而聊天实际走 Chat Completions。

如果 `/models` 拉取失败，先在 `Model IDs (Filter)` 手动添加后台确认可用的模型，再回聊天页验证。

### 页面看不到模型

按顺序检查：

| 检查项 | 处理 |
| --- | --- |
| 连接是否启用 | 回 `Connections` 打开连接开关 |
| 模型是否加入过滤列表 | 在 `Model IDs (Filter)` 添加模型并保存 |
| 模型名是否写错 | 和 UseGoodAI 后台逐字核对 |
| 页面是否缓存旧状态 | 刷新页面或重新登录 |

### 401 / Unauthorized

通常是 API Key 问题：

| 可能原因 | 处理 |
| --- | --- |
| Key 复制不完整 | 从 UseGoodAI 后台重新复制 |
| Key 被删除或禁用 | 换一个有效 Key |
| Key 填到了错误连接 | 确认填在 UseGoodAI 连接的 API Key 字段 |
| 环境变量没生效 | 重建容器后再试 |

### 403 / Forbidden

先按这个顺序查：

| 顺序 | 检查项 |
| --- | --- |
| 1 | API Key 是否有效 |
| 2 | Base URL 是否正好是 `https://api.usegoodai.com/v1` |
| 3 | 模型是否属于当前 Key 的可用分组 |
| 4 | 后台请求记录里实际接口是否是 Chat Completions |
| 5 | 是否有代理、网关或容器网络改写请求 |

普通 Open WebUI 接入一般不需要手动改 `User-Agent`。只有后台记录明确提示客户端识别异常，或客服要求时，再单独处理 Header。

### Docker 里需要写 `host.docker.internal` 吗？

连接 UseGoodAI 这种公网地址时不需要。

`host.docker.internal` 主要用于 Open WebUI 容器访问你电脑本机上的模型服务，例如本机 vLLM、LM Studio 或 Ollama 兼容接口。

### 配置了环境变量，后台里又改了连接怎么办？

先选一种方式作为准。新手建议用管理后台。

如果要回到后台配置，先移除 Docker / Compose 里的 `OPENAI_API_BASE_URL` 和 `OPENAI_API_KEY`，重建容器后再在后台保存连接。
