# 图片生成 API

使用 `gpt-image-2` 可以通过 OpenAI-compatible 图片接口生成图片。适合在自己的脚本、后台服务、自动化流程或支持图片生成接口的客户端里接入。

## 接口地址

程序或 HTTP 请求的完整端点是：

```text
POST https://api.usegoodai.com/v1/images/generations
```

如果某个客户端要求填写 `Base URL`，不要把完整端点填进去。按客户端说明填写根地址或 `/v1` 地址：

```text
https://api.usegoodai.com
```

或：

```text
https://api.usegoodai.com/v1
```

普通聊天客户端通常会自己拼接 `/chat/completions`、`/models` 等路径。不要把 `/v1/images/generations` 填进普通聊天客户端的 `Base URL`。

## 生成一张图片

先把 UseGoodAI 后台创建的 API Key 放到环境变量里：

```bash
export USEGOODAI_API_KEY="你的 API Key"
```

发送图片生成请求：

```bash
curl https://api.usegoodai.com/v1/images/generations \
  -H "Authorization: Bearer $USEGOODAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-2",
    "prompt": "为一家现代咖啡店生成一张温暖明亮的产品宣传图，画面包含一杯拿铁、一块可颂和简洁的中文标题区域。",
    "size": "1024x1024"
  }'
```

请求成功后，图片内容会在返回 JSON 的 `data[0].b64_json` 字段里。

## 保存返回的图片

`data[0].b64_json` 是 Base64 图片内容，不是图片 URL。保存图片时按下面顺序处理：

1. 从返回 JSON 里读取 `data[0].b64_json`。
2. 对这个字符串做 Base64 解码。
3. 把解码后的二进制内容写入 `.png` 文件。

下面是一个简短的 Python 示例，会把生成结果保存为 `image.png`：

```python
import base64
import os

import requests

api_key = os.environ["USEGOODAI_API_KEY"]

response = requests.post(
    "https://api.usegoodai.com/v1/images/generations",
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
    json={
        "model": "gpt-image-2",
        "prompt": "生成一张清爽的科技产品海报，包含一台笔记本电脑、柔和光线和简洁留白。",
        "size": "1024x1024",
    },
    timeout=120,
)
response.raise_for_status()

image_base64 = response.json()["data"][0]["b64_json"]
with open("image.png", "wb") as file:
    file.write(base64.b64decode(image_base64))
```

## 常用参数

不同账号、模型和接口版本的可用参数可能不同。下面只列常见参数，实际是否支持以当前接口返回为准。

| 参数 | 说明 |
| --- | --- |
| `size` | 图片尺寸，例如 `1024x1024`。具体可用尺寸以接口支持为准。 |
| `quality` | 图片质量选项。不同质量档位是否可用，以实际支持为准。 |
| `output_format` | 输出格式选项，例如需要 PNG 时可尝试设置为 `png`，以实际支持为准。 |

如果接口返回参数不支持、请求体无效或模型不可用，先删掉可选参数，只保留 `model`、`prompt` 和一个确认可用的 `size` 再测试。

## 图片编辑

图片编辑通常使用：

```text
POST https://api.usegoodai.com/v1/images/edits
```

如果账号和接口支持图片编辑，请按 `multipart/form-data` 形式提交图片文件和提示词。这个接口需要单独测试，不应直接假定所有账号、客户端或参数都已支持。

请求形态示例：

```bash
curl https://api.usegoodai.com/v1/images/edits \
  -H "Authorization: Bearer $USEGOODAI_API_KEY" \
  -F "model=gpt-image-2" \
  -F "image=@input.png" \
  -F "prompt=在保持主体不变的前提下，把背景改成明亮的办公室场景。"
```

如果编辑请求失败，先确认账号权限、模型分组、文件字段名、图片格式和接口返回错误。需要稳定上线前，建议先用最小图片和最短提示词做一次独立验证。

## 常见问题

### 浏览器直连失败或 CORS 报错

不要把 API Key 放在浏览器前端直接请求图片接口。浏览器直连可能遇到 CORS 限制，也会暴露密钥。建议由你的后端服务请求 UseGoodAI，再把生成结果或保存后的图片地址返回给前端。

### Base URL 填错

完整生图端点是 `https://api.usegoodai.com/v1/images/generations`，但普通客户端的 `Base URL` 通常只填根地址或 `/v1` 地址。不要把 `/v1/images/generations` 填进普通聊天客户端的 `Base URL`。

更多说明见 [外接兼容与 Base URL 说明](/external/base-url)。

### 模型列表能拉取，不代表生图一定能用

`GET /v1/models` 能返回模型列表，只能说明模型列表接口可访问。图片生成还要看当前 API Key 的分组、账号权限、模型可用状态和图片端点是否允许调用。

模型和分组说明见 [模型与分组](/models)。

### 返回 Base64 怎么保存

读取 `data[0].b64_json`，Base64 解码，然后把解码后的二进制内容写成 PNG 文件。它不是可直接打开的 URL，也不应该原样写进图片文件。

### 429 或 5xx 怎么处理

`429` 通常表示当前请求过快、额度不足或触发限流；`5xx` 通常表示服务端或上游临时异常。建议做短暂退避后重试，避免高频并发重放同一个请求。如果持续失败，保留请求时间、模型名、端点、错误码和返回内容，再按 [报错与踩坑](/errors/) 排查。

## 相关链接

- [模型与分组](/models)
- [报错与踩坑](/errors/)
- [外接兼容与 Base URL 说明](/external/base-url)
