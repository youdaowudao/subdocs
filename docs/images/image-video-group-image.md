# 生图分组方法

“生图与视频分组”提供 `Nano Banana`、`GPT Image`、`Adobe` 和 `Grok` 图片模型，价格见[模型价格](/models)。让 Codex 按本文创建调用脚本，并把生成结果显示在当前对话中。

需要生成视频时，进入[视频分组方法](/images/image-video-group-video)。

## 第一次使用：让 Codex 创建调用工具

把下面整段提示词发给 Codex：

```text
请完整阅读并严格按照这个页面操作：
https://docs.usegoodai.com/images/image-video-group-image.html

根据页面中的“Codex 必须遵守的调用规则”，完成以下任务：
1. 在当前文件夹创建一个可运行的单文件生图脚本，文件名为“生成图片.py”。
2. 创建或更新当前项目根目录的 AGENTS.md，保留原有内容，并写入页面规定的“项目生图规则”。
3. 除“生成图片.py”和 AGENTS.md 外，不创建其它工程文件，也不自动安装依赖。
4. 为 UseGoodAI API Key 保留一个明显的配置项，创建完成后只让我填写这个值。
5. 这个脚本是给 Codex 调用的，不要让我手动修改图片描述、模型或运行命令。
6. 脚本必须接收 Codex 每次传入的完整图片描述、模型和可选原图文件，不能把图片描述写死在脚本里。
7. 默认使用 `gpt-image-2`。用户指定 Nano Banana、Adobe、Grok 或其它允许模型时，按页面模板调用；每次调用前先告诉我本次使用的模型。
8. 每个模型请求只发送一次，禁止自动重试；用户要求模型对比时，逐个模型各请求一次。
9. 成功后保存本地图片，并立即使用 view_image 把图片显示在当前 Codex App 对话中；失败时原样显示错误并保留完整响应。
```

## 以后使用：直接告诉 Codex 画什么

配置一次 API Key 后，不再打开或修改脚本。直接对 Codex 说：

```text
画一张雨后城市街道的人物照片，电影感，自然光影，不要文字和水印。
```

Codex 会把这次要求传给 `生成图片.py`，生成成功后直接在当前对话中显示图片。

需要比较模型时，直接对 Codex 说：

```text
用同一个提示词分别调用 `nano-banana-2`、`gpt-image-2` 和 `grok-imagine-image` 各生成一张图片。每个模型只请求一次，生成后立即在 Codex App 中展示，并按模型名比较结果。
```

## 不同模型使用不同接口

Nano Banana 使用 `/v1/responses`；GPT Image、Adobe 和 Grok 使用 `/v1/images/generations`。两个接口不能互换：已经确认把 `nano-banana-2` 发送到 `/v1/images/generations` 会返回 HTTP 400，脚本必须根据模型自动选择接口。

## 让规则在当前项目长期生效

上面的提示词会让 Codex 把生图规则写入当前项目根目录的 `AGENTS.md`。以后从这个项目开始的新任务仍会读取这些规则；规则只对当前项目生效，不会修改其它项目或全局配置。

::: details Codex 必须遵守的调用规则

## 支持的生图模型和接口

| 模型 | 请求接口 | 参数规则 |
| --- | --- | --- |
| `nano-banana-2` | `/v1/responses` | 不得发送到 `/v1/images/generations` |
| `nano-banana-pro` | `/v1/responses` | 不得发送到 `/v1/images/generations` |
| `gpt-image-2` | `/v1/images/generations` | `size` 使用明确像素值 |
| `gpt-image-2-4K` | `/v1/images/generations` | `size` 使用 `2160x3840` 等明确像素值 |
| `gpt-image-1k-th` | `/v1/images/generations` | 使用 `1024x1024` |
| `gpt-image-2-adobe` | `/v1/images/generations` | 使用 `1024x1536`，完成后读取实际宽高 |
| `gpt-image-1K-adobe` | `/v1/images/generations` | 使用 `832x1248` |
| `gpt-image-2K-adobe` | `/v1/images/generations` | 使用 `1536x2304` |
| `gpt-image-4K-adobe` | `/v1/images/generations` | 使用 `2304x3456` |
| `grok-imagine-image` | `/v1/images/generations` | 只发送 `model`、`prompt` 和 `n` |

所有请求都使用同一个 API 根地址和 `Authorization` 鉴权；当前分组通过 Sub2API 按模型接入不同接口，脚本必须根据模型选择接口，不能把所有模型都发送到同一个接口。

请求方法、地址和鉴权：

```text
POST https://api.usegoodai.com/v1/responses
POST https://api.usegoodai.com/v1/images/generations
POST https://api.usegoodai.com/v1/images/edits
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

脚本默认使用 `gpt-image-2`。用户明确指定其它模型时，Codex 必须使用下面对应的完整模板，并在调用前说明模型名和接口。不同模型不能共用一个未经确认的请求体。

### Nano Banana 不能使用 Images 接口

`nano-banana-2` 已经使用下面的错误请求做过单次验证：

```text
POST https://api.usegoodai.com/v1/images/generations
```

```json
{
  "model": "nano-banana-2",
  "prompt": "<图片描述>",
  "n": 1
}
```

Sub2API 返回 HTTP 400：

```json
{
  "error": {
    "message": "images endpoint requires an image model, got \"nano-banana-2\"",
    "type": "invalid_request_error"
  }
}
```

因此，`nano-banana-2` 必须使用 `/v1/responses` 和 `input` 请求结构。`nano-banana-pro` 也使用下方已经确认的 Responses 模板；没有新的验证结果前，不能把它改发到 Images 接口。端点错误时原样返回错误并停止，不能自动重试或静默改用其它端点。

### `nano-banana-2` 请求

```json
{
  "model": "nano-banana-2",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "<运行脚本时收到的图片描述>"
        }
      ]
    }
  ],
  "stream": false
}
```

### `nano-banana-pro` 请求

```json
{
  "model": "nano-banana-pro",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "<运行脚本时收到的图片描述>"
        }
      ]
    }
  ],
  "stream": false
}
```

### GPT Image 请求

以下请求都发送到 `/v1/images/generations`，每个模型使用已测试的模型名和尺寸：

```json
{
  "model": "gpt-image-2",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "1024x1536",
  "quality": "high",
  "output_format": "png"
}
```

```json
{
  "model": "gpt-image-2",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "1536x2304",
  "quality": "high",
  "output_format": "png"
}
```

```json
{
  "model": "gpt-image-2",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "2160x3840",
  "quality": "high",
  "output_format": "png"
}
```

```json
{
  "model": "gpt-image-2-4K",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "2160x3840",
  "quality": "high",
  "output_format": "png"
}
```

```json
{
  "model": "gpt-image-1k-th",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "1024x1024",
  "quality": "high",
  "output_format": "png"
}
```

`gpt-image-2` 的三个请求分别对应 1K、2K、4K 竖图。`gpt-image-2-4K` 是独立的公开模型名，但仍必须同时发送明确的 `2160x3840`。

### Adobe 请求

Adobe 模型也发送到 `/v1/images/generations`，使用各自已经确认的尺寸：

```json
{
  "model": "gpt-image-2-adobe",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "1024x1536",
  "quality": "high",
  "output_format": "png"
}
```

```json
{
  "model": "gpt-image-1K-adobe",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "832x1248",
  "quality": "high",
  "output_format": "png"
}
```

```json
{
  "model": "gpt-image-2K-adobe",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "1536x2304",
  "quality": "high",
  "output_format": "png"
}
```

```json
{
  "model": "gpt-image-4K-adobe",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "size": "2304x3456",
  "quality": "high",
  "output_format": "png"
}
```

### Grok 请求

当前分组公开的 Grok 模型名是 `grok-imagine-image`。模型名必须原样发送，不能替换成 xAI 官方文档中的其它 Grok 模型名。

请求使用下面的地址和请求头：

```text
POST https://api.usegoodai.com/v1/images/generations
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

请求体只发送 `model`、`prompt` 和 `n`。当前调用方法没有确认 `size`、`quality`、`output_format`、宽高比或分辨率参数，脚本不得自行添加：

```json
{
  "model": "grok-imagine-image",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1
}
```

Grok 当前已经确认的一种成功响应如下。`data[].url` 是需要下载的图片地址，脚本也必须兼容 `data[].b64_json`：

```json
{
  "model": "grok-imagine-image",
  "output_format": "png",
  "quality": "standard",
  "size": "auto",
  "data": [
    {
      "mime_type": "image/jpeg",
      "url": "https://<图片地址>"
    }
  ]
}
```

返回中的 `output_format`、`mime_type` 和实际图片格式可能不一致。远程图片只下载一次，下载后检查文件签名；文件扩展名以实际图片字节为准。例如文件签名是 JPEG 时保存为 `.jpg` 或 `.jpeg`，不能因为 `output_format` 是 `png` 就保存为 `.png`。保存成功后立即使用 `view_image` 在当前 Codex App 对话中显示图片。

当前已经确认并可直接使用的 Images 编辑模板是 `gpt-image-2`：

```text
POST https://api.usegoodai.com/v1/images/edits
```

改图请求使用 `multipart/form-data`，由 Codex 传入原图文件、编辑描述和明确像素尺寸；没有输入图片时不能调用编辑接口。这里仅说明当前可直接交付的编辑模板，不代表其它图片模型一定不支持改图。

脚本必须遵守以下规则：

1. 允许使用的模型只有上方表格列出的十个模型，默认使用 `gpt-image-2`；不得改写模型名或静默替换模型。
2. 每次请求前，Codex 必须先在对话中说明本次使用的模型和请求接口，然后直接调用脚本。
3. 每次运行只发送一次请求，不自动重试，也不自行改用其它接口。Nano Banana 只能发送到 `/v1/responses`；GPT Image、Adobe 和 Grok 发送到 `/v1/images/generations`。
4. 没有图片描述、模型不在允许列表中或缺少改图原图时明确报错，不能使用脚本内置的默认提示词或其它模型。没有对应的已确认编辑模板时，只能说明当前调用方法尚未确认，不能直接宣称该模型不支持改图。
5. 保存 HTTP 状态码、响应头和原始响应体。HTTP 非 2xx 时原样显示错误并停止，不创建空图片。
6. 解析 JSON 时同时检查 Images 返回的 `data[].b64_json`、`data[].url`，以及 Responses 返回的 `output[].result`、`output[].content[]` 中的 `b64_json`、`image_base64`、`url`、`image_url`、`text` 和 `output_text`。
7. 文本字段中可能是 Markdown 图片，其中的图片可能是 Data URL，也可能是 `https://` 图片地址。Data URL 需要解码；远程图片只下载一次。
8. 只有图片字节非空且文件签名有效时才算成功。扩展名按实际图片格式保存，不能只相信 `output_format` 或 `mime_type`；两者与文件签名冲突时，以文件签名为准。
9. 图片保存成功后，Codex 必须调用 `view_image` 打开本地图片，让图片显示在当前 Codex App 对话中；不能只回复文件路径或远程链接。
10. 找不到有效图片、解码失败或下载失败时，保留完整响应并明确报错，不创建空文件。

写入当前项目根目录 `AGENTS.md` 的“项目生图规则”必须包含：

```md
## 项目生图规则

- 本项目的生图任务统一调用当前项目内的 `生成图片.py` 和 `https://api.usegoodai.com`，由模型决定使用 `/v1/responses`、`/v1/images/generations` 或已确认的 `/v1/images/edits`。
- 可用模型只有：`nano-banana-2`、`nano-banana-pro`、`gpt-image-2`、`gpt-image-2-4K`、`gpt-image-1k-th`、`gpt-image-2-adobe`、`gpt-image-1K-adobe`、`gpt-image-2K-adobe`、`gpt-image-4K-adobe`、`grok-imagine-image`。默认使用 `gpt-image-2`，不得静默替换模型。
- `nano-banana-2` 和 `nano-banana-pro` 只能使用 `/v1/responses`；不得发送到 `/v1/images/generations`。已经确认 `nano-banana-2` 发送到 Images 接口会返回 HTTP 400。GPT Image、Adobe 和 Grok 使用 `/v1/images/generations`。当前可直接交付的编辑模板是 `gpt-image-2` 使用 `/v1/images/edits`；这不代表其它模型一定不支持改图。
- `gpt-image-2` 的 1K、2K、4K 竖图尺寸分别为 `1024x1536`、`1536x2304`、`2160x3840`；`gpt-image-2-4K` 使用 `2160x3840`；`gpt-image-1k-th` 使用 `1024x1024`。
- Adobe 尺寸固定为：`gpt-image-2-adobe` 使用 `1024x1536`，`gpt-image-1K-adobe` 使用 `832x1248`，`gpt-image-2K-adobe` 使用 `1536x2304`，`gpt-image-4K-adobe` 使用 `2304x3456`。Grok 请求只发送 `model`、`prompt` 和 `n`，不添加未经确认的尺寸、质量或格式字段。
- Grok 返回同时检查 `data[].b64_json` 和 `data[].url`，远程图片只下载一次。`output_format`、`mime_type` 和文件签名冲突时，以实际文件签名决定扩展名。
- 每次调用前先在对话中告诉用户本次使用的模型和接口。图片描述、模型和参数由 Codex 在本次调用时传给脚本，不写死在脚本中。
- 用户要求模型对比时，使用同一提示词逐个调用指定模型，每个模型只请求一次，逐张展示后再比较。
- 每次生成只发送一次请求，禁止自动重试。失败时保留完整响应并原样报告错误。
- 生成成功后必须保存有效的本地图片，并立即调用 `view_image` 打开该图片，让图片显示在当前 Codex App 对话中。不得只回复文件路径或远程链接。
```

:::
