# 图片生成 API

使用 `gpt-image-2` 可以通过 OpenAI-compatible 图片接口生成图片。本文适合自己写脚本、服务端流程、自动化流程，或给支持图片生成接口的客户端填写接口信息。

最直接的效果是：本地创建一个脚本，请求图片生成接口，把返回的 Base64 图片保存成 `.png` 文件。只想手动连续创作图片，先看 [无限画布](/images/infinite-canvas)。

## 懒人方法：让 AI 帮你快速测试

把下面这段话复制给能操作本机文件的 AI。它会帮你做成一个可重复运行的单文件脚本。

```text
请帮我用最少步骤测试 UseGoodAI 图片生成 API。

要求：
1. 写一个可运行脚本，文件名用中文，例如 `生成图片.sh`、`生成图片.ps1` 或 `生成图片.py`。
2. 可以用 `curl` 发送请求；不要额外安装依赖，本机确实缺少工具时先等我确认。
3. 调用接口：POST https://api.usegoodai.com/v1/images/generations，API Key 让我自己填。
4. 请求体参考 `gpt-image-2` 图片生成调用方法，例如：
   {"model":"gpt-image-2","prompt":"生成一张白底玻璃杯产品图","size":"1024x1024"}
5. 把原始返回保存为 response.json，再把 data[0].b64_json 解码成 outputs/image.png；失败时显示状态码和返回内容。
```

测试跑通后，再根据自己的业务改提示词、输出文件名、批量读取方式和错误处理。

## 接口地址

程序或 HTTP 请求的完整端点是：

```text
POST https://api.usegoodai.com/v1/images/generations
```

客户端要求填写 `Base URL` 时，不要把完整端点填进去。按客户端说明填写根地址或 `/v1` 地址：

```text
https://api.usegoodai.com
```

或：

```text
https://api.usegoodai.com/v1
```

普通聊天客户端会自己拼接 `/chat/completions`、`/models` 等路径。不要把 `/v1/images/generations` 填进普通聊天客户端的 `Base URL`。

## 生成一张图片

先把 UseGoodAI 后台创建的 API Key 放到环境变量里。

macOS / Linux / WSL：

```bash
export USEGOODAI_API_KEY="你的 API Key"
```

Windows PowerShell：

```powershell
$env:USEGOODAI_API_KEY="你的 API Key"
```

发送图片生成请求，并把原始返回保存为 `response.json`：

```bash
curl https://api.usegoodai.com/v1/images/generations \
  -H "Authorization: Bearer $USEGOODAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-2",
    "prompt": "为一家现代咖啡店生成一张温暖明亮的产品宣传图，画面包含一杯拿铁、一块可颂和简洁的中文标题区域。",
    "size": "1024x1024"
  }' \
  -o response.json
```

请求成功后，图片内容会在返回 JSON 的 `data[0].b64_json` 字段里。

## 保存返回的图片

`data[0].b64_json` 是 Base64 图片内容，不是图片 URL。保存图片时按下面顺序处理：

1. 从返回 JSON 里读取 `data[0].b64_json`。
2. 对这个字符串做 Base64 解码。
3. 把解码后的二进制内容写入 `.png` 文件。

下面用 Python 标准库把 `response.json` 里的图片保存为 `outputs/image.png`：

```python
import base64
import json
import os

with open("response.json", "r", encoding="utf-8") as file:
    response = json.load(file)

image_base64 = response["data"][0]["b64_json"]
os.makedirs("outputs", exist_ok=True)
with open("outputs/image.png", "wb") as file:
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

图片编辑接口是：

```text
POST https://api.usegoodai.com/v1/images/edits
```

如果账号和接口支持图片编辑，按 `multipart/form-data` 形式提交图片文件和提示词。这个接口需要单独测试，不要直接假定所有账号、客户端或参数都已支持。

请求形态示例：

```bash
curl https://api.usegoodai.com/v1/images/edits \
  -H "Authorization: Bearer $USEGOODAI_API_KEY" \
  -F "model=gpt-image-2" \
  -F "image=@input.png" \
  -F "prompt=在保持主体不变的前提下，把背景改成明亮的办公室场景。"
```

如果编辑请求失败，先确认账号权限、模型分组、文件字段名、图片格式和接口返回错误。稳定上线前，先用最小图片和最短提示词做一次独立验证。

## 常见问题

### 浏览器直连失败或 CORS 报错

不要把 API Key 放在浏览器前端直接请求图片接口。浏览器直连可能遇到 CORS 限制，也会暴露密钥。由你的后端服务请求 UseGoodAI，再把生成结果或保存后的图片地址返回给前端。

### Base URL 填错

完整生图端点是 `https://api.usegoodai.com/v1/images/generations`，但普通客户端的 `Base URL` 只填根地址或 `/v1` 地址。不要把 `/v1/images/generations` 填进普通聊天客户端的 `Base URL`。

更多说明见 [外接兼容与 Base URL 说明](/external/base-url)。

### 模型列表能拉取，不代表生图一定能用

`GET /v1/models` 能返回模型列表，只能说明模型列表接口可访问。图片生成还要看当前 API Key 的分组、账号权限、模型可用状态和图片端点是否允许调用。

模型和分组说明见 [模型与分组](/models)。

### 保存后的文件打不开

检查是不是把 `data[0].b64_json` 原样写进了图片文件。正确做法是先 Base64 解码，再把解码后的二进制内容写成 PNG 文件。它不是可直接打开的 URL。

### 429 或 5xx 怎么处理

`429` 表示当前请求过快、额度不足或触发限流；`5xx` 表示服务端或上游临时异常。先做短暂退避后重试，避免高频并发重放同一个请求。如果持续失败，保留请求时间、模型名、端点、错误码和返回内容，再按 [报错与踩坑](/errors/) 排查。
