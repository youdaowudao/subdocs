# LibreChat 接入

LibreChat 适合已经部署好网页聊天站，想把 UseGoodAI 作为 OpenAI-compatible 自定义服务接进去的用户。

::: tip 最短结论
在 LibreChat 里新增一个 `endpoints.custom`，Base URL 填 `https://api.usegoodai.com/v1`，API Key 放进 `.env`，模型名填 UseGoodAI 后台分组里实际可用的模型。
:::

## 适合谁

| 你的情况 | 是否适合 |
| --- | --- |
| 已经有 LibreChat 实例 | 适合 |
| 会编辑 `.env` 和 `librechat.yaml` | 适合 |
| 用 Docker / Docker Compose 部署 | 适合 |
| 想做多人网页聊天入口 | 适合 |
| 只想安装一个客户端马上聊天 | 不适合，优先看 Cherry Studio |

## 需要准备什么

| 项目 | 填什么 |
| --- | --- |
| LibreChat | 已安装并能打开网页 |
| API Key | 从 UseGoodAI 后台复制 |
| Base URL | `https://api.usegoodai.com/v1` |
| 接入方式 | OpenAI-compatible / Chat Completions 兼容路径 |
| 模型名 | 以后台分组里实际可用模型为准，例如 `gpt-5.5` |
| 配置文件 | `.env`、`librechat.yaml`；Docker 部署还要 `docker-compose.override.yml` |

::: warning 不要把 Base URL 写到接口路径
这里只填 `https://api.usegoodai.com/v1`。不要再追加 `/chat/completions`，LibreChat 会自己拼接聊天接口路径。
:::

## 安装或已有部署前提

如果你还没有 LibreChat，先按官方 Docker 方式启动：

```bash
git clone https://github.com/danny-avila/LibreChat.git
cd LibreChat
cp .env.example .env
docker compose up -d
```

Windows 用户如果没有 `cp` 命令，可以把 `.env.example` 手动复制一份，命名为 `.env`。

启动后通常访问：

```text
http://localhost:3080
```

如果你已经能打开 LibreChat，直接从下一步开始。

## 配置入口

LibreChat 自定义 endpoint 通常涉及 3 个文件：

| 文件 | 作用 |
| --- | --- |
| `.env` | 保存 UseGoodAI API Key |
| `librechat.yaml` | 声明自定义 endpoint、Base URL、模型列表 |
| `docker-compose.override.yml` | Docker 部署时，把 `librechat.yaml` 挂载进容器 |

如果你不是 Docker 部署，只要确保 LibreChat 运行时能读到项目根目录的 `librechat.yaml`。

## 配置步骤

### 1. 在 `.env` 写入 API Key

在 LibreChat 项目根目录的 `.env` 里添加一行：

```dotenv
USEGOODAI_API_KEY=替换为你的UseGoodAI后台APIKey
```

需要替换的值：

| 示例值 | 替换成 |
| --- | --- |
| `替换为你的UseGoodAI后台APIKey` | UseGoodAI 后台复制出来的真实 API Key |

不要把真实 Key 提交到公开仓库。

### 2. 在 `librechat.yaml` 添加 UseGoodAI

在 LibreChat 项目根目录创建或编辑 `librechat.yaml`：

```yaml
version: 1.3.13

endpoints:
  custom:
    - name: "UseGoodAI"
      apiKey: "${USEGOODAI_API_KEY}"
      baseURL: "https://api.usegoodai.com/v1"
      models:
        default:
          - "gpt-5.5"
        fetch: false
      titleConvo: true
      titleModel: "gpt-5.5"
      modelDisplayLabel: "UseGoodAI"
```

需要替换的值：

| 示例值 | 替换规则 |
| --- | --- |
| `gpt-5.5` | 换成 UseGoodAI 后台分组里实际可用的模型名 |
| `USEGOODAI_API_KEY` | 如果你在 `.env` 用了别的变量名，这里要同步改 |

::: tip 先固定模型列表
第一次接入建议保留 `fetch: false`，手动写 1 个确认可用的模型。跑通后再增加其它模型，排查会简单很多。
:::

### 3. Docker 部署挂载 `librechat.yaml`

如果你用 Docker / Docker Compose 部署，项目根目录添加或编辑 `docker-compose.override.yml`：

```yaml
services:
  api:
    volumes:
      - type: bind
        source: ./librechat.yaml
        target: /app/librechat.yaml
```

如果你已经有 `docker-compose.override.yml`，只把上面的 `volumes` 挂载合并进去，不要覆盖原有配置。

### 4. 重启 LibreChat

保存文件后重启：

```bash
docker compose down
docker compose up -d
```

如果你不是 Docker 部署，用你自己的进程管理方式重启 LibreChat。

## 模型处理

| 场景 | 做法 |
| --- | --- |
| 第一次接入 | `fetch: false`，只写一个后台确认可用的模型 |
| 想显示多个模型 | 在 `default` 下继续追加模型名 |
| 模型列表拉取失败 | 不影响手动模型，先继续用 `fetch: false` |
| 聊天时报模型不存在 | 回到 UseGoodAI 后台核对模型名和 API Key 所属分组 |

示例：追加第二个模型时这样写：

```yaml
models:
  default:
    - "gpt-5.5"
    - "替换为另一个后台可用模型名"
  fetch: false
```

## 验证方法

打开 LibreChat，按顺序检查：

1. 模型选择器里能看到 `UseGoodAI`。
2. 能选择你在 `librechat.yaml` 里写的模型。
3. 发送测试消息：

```text
请用一句话回复：LibreChat 已连接成功
```

如果能正常回复，说明 LibreChat 到 UseGoodAI 的 OpenAI-compatible Chat Completions 兼容链路已经通了。

## 常见错误

### 页面里看不到 UseGoodAI

| 检查项 | 处理 |
| --- | --- |
| `librechat.yaml` 是否在项目根目录 | 放到和 `.env` 同级的位置 |
| Docker 是否挂载配置 | 检查 `docker-compose.override.yml` |
| 是否重启服务 | 重新执行 `docker compose down && docker compose up -d` |
| YAML 是否校验失败 | 查看 `docker compose logs api` |

### 服务启动失败

通常是 `librechat.yaml` 格式问题。优先检查：

| 位置 | 正确写法 |
| --- | --- |
| `version` | 顶格写，例如 `version: 1.3.13` |
| `endpoints.custom` | 保持 YAML 缩进，不要用 Tab |
| `apiKey` | 写成 `"${USEGOODAI_API_KEY}"` |
| `baseURL` | 只写 `https://api.usegoodai.com/v1` |

查看日志：

```bash
docker compose logs api
```

### 聊天时报 401 / Unauthorized

| 可能原因 | 处理 |
| --- | --- |
| API Key 复制错 | 回 UseGoodAI 后台重新复制 |
| `.env` 没被读取 | 确认变量名和 `apiKey: "${USEGOODAI_API_KEY}"` 一致 |
| 改完没重启 | 重启 LibreChat |

### 聊天时报模型不存在

| 可能原因 | 处理 |
| --- | --- |
| 模型名写错 | 复制后台分组里的真实模型名 |
| API Key 所属分组不支持该模型 | 换成当前 Key 分组可用的模型 |
| 一次写了太多模型 | 先缩小到 1 个模型验证 |

### 要不要写 `provider: anthropic`

不用。UseGoodAI 这里按 OpenAI-compatible / Chat Completions 兼容路径接入。

`provider: "anthropic"` 只用于原生 Anthropic Messages API endpoint。这里不要加，否则会走错协议。

### Base URL 到底写什么

只写：

```text
https://api.usegoodai.com/v1
```

不要写：

```text
https://api.usegoodai.com/v1/chat/completions
```

## 下一步排查

| 现象 | 优先看 |
| --- | --- |
| 页面没有 `UseGoodAI` | `librechat.yaml` 是否挂载、是否重启 |
| 服务起不来 | `docker compose logs api` 里的 YAML 校验错误 |
| 能看到模型但不能聊 | API Key、模型名、后台分组权限 |
| 不确定模型名 | 回 UseGoodAI 后台查看当前 Key 所属分组 |
