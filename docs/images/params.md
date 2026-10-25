# 生图参数汇总

自己写脚本或调用接口时查本页。API Key 使用 **专门画图分组** 的 Key，价格看 [模型价格](/models)。

## 接口和鉴权

根地址 `https://api.usegoodai.com`，请求头 `Authorization: Bearer <API_KEY>`。

| 模型 | 文生图 | 参考图和修图 | 尺寸参数 |
| --- | --- | --- | --- |
| `gpt-image-2.5-flare` | `POST /v1/images/generations` | `POST /v1/images/edits` | `size` |
| `gpt-image-2.5-sunburst` | `POST /v1/images/generations` | `POST /v1/images/edits` | `size` |
| `gpt-image-2` | `POST /v1/images/generations` | `POST /v1/images/edits` | `size` |
| `gpt-image-1k-th` | `POST /v1/images/generations` | `POST /v1/images/edits` | 固定 `1024x1024` |
| `gpt-image-2-adobe` | `POST /v1/images/generations` | 不支持 | 三个固定尺寸 |
| `grok-imagine-image` | `POST /v1/images/generations` | `POST /v1/images/edits` | `resolution` + `aspect_ratio` |
| `nano-banana-2` | `POST /v1/responses` | `POST /v1/responses` | `image_size` + `aspect_ratio` |
| `nano-banana-pro` | `POST /v1/responses` | `POST /v1/responses` | `image_size` + `aspect_ratio` |

`/v1/images/edits` 用 `multipart/form-data` 上传：一张图字段名 `image`，多张图用 `image[]`。Nano Banana 把图片放进请求体，见下文。

## GPT Image 2.5 {#gpt-image-2-5}

`gpt-image-2.5-flare` 适合普通生图和批量任务，`gpt-image-2.5-sunburst` 适合高清、精修和重要成品。两个模型参数相同，都支持文生图、参考图、修图和多图，使用 `size`、`quality` 和 `output_format`，不使用 `resolution` 或 `aspect_ratio`。

| 参数 | 写法 |
| --- | --- |
| `prompt` | 必填，完整图片描述或修改指令 |
| `size` | `auto` 或 `WIDTHxHEIGHT`：宽高为 16 的倍数，单边不超过 3840，长短边比例不超过 3:1，总像素为 655360 至 8294400 |
| `quality` | `low`、`medium`、`high`、`xhigh`、`max`、`auto` |
| `output_format` | `png` |
| `n` | `1` 至 `10` |

省略 `size` 或 `quality` 时两者默认 `auto`；`size=auto` 时模型根据提示词选择尺寸。`xhigh` 和 `max` 只适用于两个 GPT Image 2.5 模型。

### 1K、2K、4K 对应的 `size`

1K、2K、4K 不能直接填进 `size`，按下表换成像素：

| 用户要求 | `size` |
| --- | --- |
| 1K 方图 | `1024x1024` |
| 1K 横图 | `1536x1024` |
| 1K 竖图 | `1024x1536` |
| 2K 方图 | `2048x2048` |
| 2K 横图 | `2048x1152` |
| 2K 竖图 | `1152x2048` |
| 4K 横图 | `3840x2160` |
| 4K 竖图 | `2160x3840` |

最大方图是 `2880x2880`（总像素上限）。超过 `2560x1440` 的输出属于实验性范围。

### 按比例对应的 `size`

| 比例 | `size` |
| --- | --- |
| 1:1 | `1024x1024` |
| 3:2 | `1152x768` |
| 2:3 | `768x1152` |
| 3:4 | `768x1024` |
| 4:3 | `1024x768` |
| 4:5 | `768x960` |
| 5:4 | `960x768` |
| 9:16 | `720x1280` |
| 16:9 | `1280x720` |
| 21:9 | `1344x576` |
| 9:21 | `576x1344` |
| 3:1 | `1536x512` |
| 1:3 | `512x1536` |

比例超过 3:1 的 `4:1`、`1:4`、`8:1`、`1:8` 不支持。

## GPT Image 2

和 GPT Image 2.5 的差异只有 `quality`：可选 `low`、`medium`、`high`、`auto`，不支持 `xhigh` 和 `max`。

## GPT Image 1K TH

| 参数 | 写法 |
| --- | --- |
| `size` | 只能 `1024x1024` |
| `quality` | `low` 或 `high` |
| `n` | `1` 至 `10` |

只出 1K 方图，2K、4K 和其它比例会被拒绝。需要其它尺寸时换 GPT Image 2.5。

## GPT Image 2 Adobe

| 参数 | 写法 |
| --- | --- |
| `size` | `1024x1536`、`1536x2304`、`2304x3456`（都是 2:3 竖图） |
| `quality` | 只能 `low` |
| `n` | `1` 至 `10` |

只能文生图，不支持参考图和修图。

## Grok Imagine

| 参数 | 写法 |
| --- | --- |
| `resolution` | `1k`、`2k` |
| `aspect_ratio` | `1:1`、`16:9`、`9:16`、`4:3`、`3:4`、`3:2`、`2:3` |
| `quality` | `low`、`medium`、`high`；不填使用模型默认值 |
| `n` | `1` 至 `9` |
| `response_format` | `b64_json` |

不能发送 `size`。参考图和修图时不传 `resolution`、`aspect_ratio` 和 `quality`，按原图规格输出。

实测交付文件固定为 `768x1152`，不随 `resolution` 和 `aspect_ratio` 变化。需要确定尺寸或比例时，不用 Grok。

## Nano Banana 2 和 Nano Banana Pro

两个模型都走 `POST /v1/responses`，文字、参考图和修改指令都放在 `input[0].content` 里，不能写成顶层 `prompt` 或 `images` 字段。

| 参数 | 写法 |
| --- | --- |
| `response_format.image_size` | Nano Banana 2：`512`、`1K`、`2K`、`4K`；Nano Banana Pro：`1K`、`2K`、`4K` |
| `response_format.aspect_ratio` | `1:1`、`3:2`、`2:3`、`3:4`、`4:3`、`4:5`、`5:4`、`9:16`、`16:9`、`21:9`、`9:21`、`1:4`、`4:1`、`1:8`、`8:1` |
| `response_format.mime_type` | `image/png` |
| `stream` | `false` |
| 多图 | 不支持 `n`，每张图单独发一次请求 |
| 参考图 | PNG、JPEG、WebP 的 Data URL；Nano Banana 2 已验证 1、2、4 张 |

不使用 `quality`、`size` 和 `output_format`。

最小请求体：

```json
{
  "model": "nano-banana-2",
  "input": [{
    "role": "user",
    "content": [{
      "type": "input_text",
      "text": "一只红苹果放在白色桌面上"
    }]
  }],
  "stream": false,
  "response_format": {
    "type": "image",
    "mime_type": "image/png",
    "aspect_ratio": "1:1",
    "image_size": "1K"
  }
}
```

带参考图或修图时，在同一个 `content` 数组里加：

```json
{
  "type": "input_image",
  "image_url": "data:image/png;base64,<图片的Base64内容>"
}
```

Nano Banana Pro 实测交付文件都是 `1024x1024`，2K、4K、横图和竖图参数不生效。需要确定尺寸或比例时，不用 Nano Banana Pro。

## 读取返回的图片

| 接口 | 图片位置 |
| --- | --- |
| `/v1/images/generations`、`/v1/images/edits` | `data[].b64_json`（Base64 解码）或 `data[].url`（下载一次）；两者都有时用 Base64 |
| `/v1/responses` | 只在 `output` 里找：结构化图片、Markdown 里的 Data URL 或 HTTPS 图片链接 |

图片字节非空、文件头是有效 PNG 或 JPEG 才算成功，扩展名按实际格式决定。没有有效图片时报错，不写空文件。
