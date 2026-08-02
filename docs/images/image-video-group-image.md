# 生图分组方法

“生图分组”提供 `Nano Banana`、`GPT Image`、`Adobe` 和 `Grok` 图片模型，价格见[模型价格](/models)。让 Codex 按下面步骤创建调用脚本，并把生成结果显示在当前对话中。

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

## 不同任务使用对应接口

Nano Banana 使用 `/v1/responses`；GPT Image、Adobe 和 Grok 生成图片使用 `/v1/images/generations`；已确认的图片编辑使用 `/v1/images/edits`。这些接口不能互换：已经确认把 `nano-banana-2` 发送到 `/v1/images/generations` 会返回 HTTP 400，脚本必须根据模型和生成、编辑任务自动选择接口。

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
| `grok-imagine-image` | 生成：`/v1/images/generations`<br>编辑：`/v1/images/edits` | 普通版；生成、编辑；支持 1K/2K |
| `grok-imagine-image-quality` | 生成：`/v1/images/generations`<br>编辑：`/v1/images/edits` | 高质量版；生成、编辑；支持 1K/2K |

所有请求都使用同一个 API 根地址和 `Authorization` 鉴权；当前分组通过 Sub2API 按模型接入不同接口，脚本必须根据模型选择接口，不能把所有模型都发送到同一个接口。

请求方法、地址和鉴权：

```text
POST https://api.usegoodai.com/v1/responses
POST https://api.usegoodai.com/v1/images/generations
POST https://api.usegoodai.com/v1/images/edits
Authorization: Bearer <API_KEY>
```

`/v1/responses` 和 `/v1/images/generations` 使用 JSON。`/v1/images/edits` 使用 `multipart/form-data`，由客户端自动生成 boundary，不能手动填写 `Content-Type`。

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

### Grok 生成与编辑

当前分组只公开下面两个 Grok 图片模型：

| 模型 | 用途 | 分辨率 |
| --- | --- | --- |
| `grok-imagine-image` | 普通版图片生成与编辑 | 1K、2K |
| `grok-imagine-image-quality` | 高质量图片生成与编辑 | 1K、2K |

原有的 `grok-imagine-image` 仍然可用。旧脚本只发送 `model`、`prompt` 和 `n` 时仍可生成图片，但“只能发送这三个字段”的限制已经失效；当前已确认生成接口支持 `aspect_ratio` 和 `resolution`。

#### Grok 生成请求

```text
POST https://api.usegoodai.com/v1/images/generations
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

```json
{
  "model": "grok-imagine-image",
  "prompt": "<运行脚本时收到的图片描述>",
  "n": 1,
  "aspect_ratio": "3:4",
  "resolution": "2k"
}
```

高质量生成只把 `model` 改为 `grok-imagine-image-quality`，其它字段不变。高质量由模型名决定，不能给普通版增加 `quality: "high"` 代替。

| 字段 | 填写方法 |
| --- | --- |
| `model` | 只能填写 `grok-imagine-image` 或 `grok-imagine-image-quality` |
| `prompt` | 必填，填写完整图片描述 |
| `n` | 当前使用 `1`；需要多张时由 Codex 逐个请求，不能自动重试 |
| `aspect_ratio` | 可选：`1:1`、`16:9`、`9:16`、`4:3`、`3:4`、`3:2`、`2:3`、`2:1`、`1:2`、`19.5:9`、`9:19.5`、`20:9`、`9:20`、`auto` |
| `resolution` | 可选：`1k` 或 `2k`；当前不支持 `4k` |

不发送 `aspect_ratio` 或 `resolution` 时由模型选择画幅和尺寸。当前 Grok 生成模板使用 `aspect_ratio` 和 `resolution`，不添加 GPT Image 使用的 `size`、`quality` 或 `output_format`。

#### Grok 编辑请求

```text
POST https://api.usegoodai.com/v1/images/edits
Authorization: Bearer <API_KEY>
```

```bash
curl https://api.usegoodai.com/v1/images/edits \
  -H "Authorization: Bearer <API_KEY>" \
  -F "model=grok-imagine-image" \
  -F "prompt=<运行脚本时收到的编辑描述>" \
  -F "image[]=@<原图路径>" \
  -F "n=1"
```

高质量编辑只把 `model` 改为 `grok-imagine-image-quality`。客户端必须自动生成 multipart boundary，不能手动设置 `Content-Type`；没有原图时不能调用编辑接口。

| 字段 | 填写方法 |
| --- | --- |
| `model` | 只能填写 `grok-imagine-image` 或 `grok-imagine-image-quality` |
| `prompt` | 必填，直接描述要修改的内容和必须保留的内容 |
| `image[]` | 必填，上传完整可读的原图；当前单图模板已经验证 |
| `n` | 当前使用 `1` |

当前确认的单图编辑模板不发送 `aspect_ratio`、`resolution`、`size`、`quality` 或 `output_format`，输出保持原图画幅。需要控制生成图片的画幅和分辨率时，在生成请求中使用 `aspect_ratio` 和 `resolution`。

#### Grok 返回结果

生成和编辑都从 `data[]` 读取结果。优先读取有效的 `data[].b64_json`，没有 Base64 时下载 `data[].url`：

```json
{
  "data": [
    {
      "mime_type": "image/jpeg",
      "url": "https://<图片地址>"
    }
  ]
}
```

远程图片只下载一次，下载后检查文件签名；文件扩展名以实际图片字节为准，不能只依赖返回的格式字段。已经复测到响应顶层返回 `output_format: "png"`、`data[].mime_type` 返回 `image/jpeg`，实际文件也是 JPEG；这种情况必须保存为 `.jpg` 或 `.jpeg`。保存成功后立即使用 `view_image` 在当前 Codex App 对话中显示图片。

脚本必须遵守以下规则：

1. 允许使用的模型只有上方表格列出的十一个模型，默认使用 `gpt-image-2`；不得改写模型名或静默替换模型。
2. 每次请求前，Codex 必须先在对话中说明本次使用的模型和请求接口，然后直接调用脚本。
3. 每次运行只发送一次请求，不自动重试，也不自行改用其它接口。Nano Banana 只能发送到 `/v1/responses`；GPT Image、Adobe 和 Grok 生成图片使用 `/v1/images/generations`；已确认的 GPT Image 和 Grok 编辑使用 `/v1/images/edits`。
4. 没有图片描述、模型不在允许列表中或缺少改图原图时明确报错，不能使用脚本内置的默认提示词或其它模型。`grok-imagine-image` 和 `grok-imagine-image-quality` 已有确认的编辑模板；其它模型没有对应的已确认编辑模板时，只能说明当前调用方法尚未确认，不能直接宣称该模型不支持改图。
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
- 可用模型只有：`nano-banana-2`、`nano-banana-pro`、`gpt-image-2`、`gpt-image-2-4K`、`gpt-image-1k-th`、`gpt-image-2-adobe`、`gpt-image-1K-adobe`、`gpt-image-2K-adobe`、`gpt-image-4K-adobe`、`grok-imagine-image`、`grok-imagine-image-quality`。默认使用 `gpt-image-2`，不得静默替换模型。
- `nano-banana-2` 和 `nano-banana-pro` 只能使用 `/v1/responses`；不得发送到 `/v1/images/generations`。已经确认 `nano-banana-2` 发送到 Images 接口会返回 HTTP 400。GPT Image、Adobe 和 Grok 生成图片使用 `/v1/images/generations`；已确认的 GPT Image 和 Grok 编辑使用 `/v1/images/edits`。
- `gpt-image-2` 的 1K、2K、4K 竖图尺寸分别为 `1024x1536`、`1536x2304`、`2160x3840`；`gpt-image-2-4K` 使用 `2160x3840`；`gpt-image-1k-th` 使用 `1024x1024`。
- Adobe 尺寸固定为：`gpt-image-2-adobe` 使用 `1024x1536`，`gpt-image-1K-adobe` 使用 `832x1248`，`gpt-image-2K-adobe` 使用 `1536x2304`，`gpt-image-4K-adobe` 使用 `2304x3456`。Grok 生成支持 `aspect_ratio` 和 `resolution`，`resolution` 只能使用 `1k` 或 `2k`；普通版使用 `grok-imagine-image`，高质量版使用 `grok-imagine-image-quality`，不能使用 `quality: "high"` 切换。Grok 编辑使用 multipart 的 `model`、`prompt`、`image[]` 和 `n`。
- Grok 返回同时检查 `data[].b64_json` 和 `data[].url`，远程图片只下载一次。`output_format`、`mime_type` 和文件签名冲突时，以实际文件签名决定扩展名。
- 每次调用前先在对话中告诉用户本次使用的模型和接口。图片描述、模型和参数由 Codex 在本次调用时传给脚本，不写死在脚本中。
- 用户要求模型对比时，使用同一提示词逐个调用指定模型，每个模型只请求一次，逐张展示后再比较。
- 每次生成只发送一次请求，禁止自动重试。失败时保留完整响应并原样报告错误。
- 生成成功后必须保存有效的本地图片，并立即调用 `view_image` 打开该图片，让图片显示在当前 Codex App 对话中。不得只回复文件路径或远程链接。
```

:::
