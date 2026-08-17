---
title: 安装生图工具
---

# 安装生图工具

UseGoodAI 中转站生图工具让 Codex 直接生成、修改并展示图片，适合已经完成[快速开始](/quick-start)、希望在 Codex 对话中使用图片模型的用户。

安装后，Codex 会自动调用工具并把成品图显示在当前对话中。安装器会写入 `$CODEX_HOME/tools/usegoodai-imagines-tool/`、`$CODEX_HOME/skills/usegoodai-image-generation/` 和 `$CODEX_HOME/AGENTS.md`；用户不需要手动修改这些文件。

## 1. 创建专门画图分组的 API Key

进入 UseGoodAI 管理后台的 **API 密钥** 页面，额外创建一个 API Key，名称可以填写“画图专用”。

把这个 Key 的分组设置为 **专门画图分组**，保存后点击复制。这里使用的不是快速开始中配置 Codex 对话模型的普通 Key，两个 Key 不要复制反。

安装器无法判断 Key 是否来自正确分组，复制前必须自己核对分组名称。

<a class="doc-image-link" href="/images/画图/画图专用分组.jpg" target="_blank" rel="noopener">
  <img src="/images/画图/画图专用分组.jpg" alt="在 API 密钥页面核对专门画图分组并复制画图专用 API Key">
</a>

## 2. 在终端安装生图工具

Windows 按 `Win + X`，点击 **终端** 或 **Windows PowerShell**，粘贴运行：

```powershell
irm https://docs.usegoodai.com/install/usegoodai-imagines-tool/install.ps1 | iex
```

看到“请粘贴专门画图分组的 Key”时，粘贴第 1 步复制的 Key，然后按回车。安装器只会下载 Windows x64 程序，不需要 Python、Node 或管理员权限。

<details>
<summary>Mac 用户看这里</summary>

Apple Silicon 和 Intel Mac 使用同一条命令，安装脚本会自动识别芯片。打开终端运行：

```bash
curl -fsSL https://docs.usegoodai.com/install/usegoodai-imagines-tool/install.sh | bash
```

看到 Key 输入提示后，粘贴第 1 步复制的专门画图分组 Key，然后按回车。安装器只下载当前 Mac 对应的一个程序。

</details>

## 3. 打开 Codex 开始生图

安装完成后打开 Codex，新建一个任务。Codex 已经打开时不用退出应用，直接新建任务即可；不要沿用安装前的旧对话。

先发送下面这句话了解入口和可用模型：

```text
介绍一下中转站生图工具怎么使用，有哪些模型。
```

随后直接描述要画的内容：

```text
画一张白底红苹果。
```

生成成功后，图片会直接显示在当前 Codex 对话中，不会只返回文件路径。

<details>
<summary>查看常用说法</summary>

直接生图：

```text
画一张雨后城市街道的人物照片，电影感，自然光影，不要文字和水印。
```

指定模型：

```text
使用 nano-banana-pro 画一张中式庭院夜景。
```

使用参考图或修改图片：

```text
参考当前文件夹里的产品照片，生成一张白底电商主图。
```

```text
把这张图片的背景改成浅灰色，保留主体不变。
```

一次生成多张：

```text
按同一个要求生成 3 张图片，并全部显示在对话中。
```

对比模型：

```text
用同一个要求分别调用 gpt-image-2 和 nano-banana-pro，各生成一张并显示出来。
```

</details>

<details>
<summary>查看支持的模型</summary>

| 模型 | 适合的调用方式 |
| --- | --- |
| `gpt-image-2` | 默认模型，支持生图、参考图、修图和多图 |
| `gpt-image-1k-th` | 1K 生图、参考图、修图和多图 |
| `gpt-image-2-adobe` | 1K、2K、4K 竖图和多图 |
| `grok-imagine-image` | 1K、2K 生图、参考图、修图和多图 |
| `nano-banana-2` | 生图、参考图、修图和多图 |
| `nano-banana-pro` | 生图、参考图、修图和多图 |

Codex 会按照用户明确提出的模型、数量、尺寸和画面要求调用工具，不会替用户决定创作内容。价格见[模型价格](/models)。

</details>

<details>
<summary>查看更新、安装位置和卸载方式</summary>

需要更新时，直接对 Codex 说：

```text
更新生图工具。
```

已经保存专门画图分组 Key 时，更新不会要求再次输入。

默认安装位置：

| 内容 | 位置 |
| --- | --- |
| 工具和专门画图 Key | `$CODEX_HOME/tools/usegoodai-imagines-tool/` |
| 生图 Skill | `$CODEX_HOME/skills/usegoodai-image-generation/` |
| Codex 全局调用规则 | `$CODEX_HOME/AGENTS.md` |

未设置 `CODEX_HOME` 时，Windows 使用 `C:\Users\你的用户名\.codex\`，Mac 使用 `~/.codex/`。生成图片保存在当前项目的 `images` 文件夹；没有打开项目时保存在桌面的 `images` 文件夹。

需要卸载时，直接对 Codex 说“卸载中转站生图工具”。专门画图 Key 默认保留，永久删除前需要单独确认。

</details>

<details>
<summary>安装或生图失败先看这里</summary>

| 遇到的问题 | 检查动作 |
| --- | --- |
| 安装器提示 Key 无效或生图返回鉴权错误 | 回到 API 密钥页面，确认复制的是 **专门画图分组** 的 Key，再重新安装 |
| 安装后 Codex 不知道生图工具 | 新建一个 Codex 任务，不要继续使用安装前的旧对话 |
| Codex 只回复图片路径或图片只出现在折叠的中间过程 | 确认当前任务已经读取生图 Skill；最终回复必须用绝对路径 Markdown 图片语法再次嵌入图片 |
| 生图接口返回错误 | 本次请求会直接停止，不会自动重试或更换模型；稍后重新发起一次新请求 |
| 图片无法写入 | 打开一个有写入权限的项目后再试，或让 Codex 使用桌面 `images` 文件夹 |

</details>

<details>
<summary>不用一键安装：让 Codex 创建 Python 脚本</summary>

这个方法适合不使用一键安装器、希望把生图脚本和规则只放在当前项目中的用户。脚本和规则只对当前项目生效，不会安装全局 Skill。

把下面整段提示词发给 Codex：

```text
请完整阅读并严格按照这个页面操作：
https://docs.usegoodai.com/image-video-group-image.html

根据页面末尾“自建 Python 脚本必须遵守的规则”，完成以下任务：
1. 在当前文件夹创建一个可运行的单文件生图脚本，文件名为“生成图片.py”。
2. 创建或更新当前项目根目录的 AGENTS.md，保留原有内容，并写入页面规定的“项目生图规则”。
3. 除“生成图片.py”和 AGENTS.md 外，不创建其它工程文件，也不自动安装依赖。
4. 为 UseGoodAI API Key 保留一个明显的配置项，创建完成后只让我填写这个值。
5. 脚本是给 Codex 调用的，不要让我手工修改图片描述、模型或运行命令。
6. 脚本必须接收 Codex 每次传入的完整图片描述、模型、数量、规格和可选原图文件，不能把图片描述写死在脚本里。
7. 默认使用 gpt-image-2；用户指定其它已支持模型时，按页面中的模型和接口映射发送请求。
8. 每个模型请求只发送一次，禁止自动重试或静默更换模型。
9. 成功后只保存最终图片，并立即使用 view_image 打开每张图片，确认图片能够正常显示。
10. view_image 成功后，最终回复仍必须用绝对路径 Markdown 图片语法再次嵌入每张图片，例如：`![生成结果](/absolute/path/image.png)`。不得只依赖中间工具输出，也不得只回复普通文件路径或普通 Markdown 文件链接。失败时显示脱敏错误，不创建空图片或运行记录。
```

以后在这个项目中直接对 Codex 说“画一张……”即可。需要比较模型时，明确说出模型名；Codex 应使用同一要求逐个调用，每个模型只请求一次。

</details>

<details>
<summary>自建 Python 脚本必须遵守的规则</summary>

### 支持的模型和接口

| 模型 | 生成接口 | 参考图和修图 |
| --- | --- | --- |
| `gpt-image-2` | `/v1/images/generations` | `/v1/images/edits` |
| `gpt-image-1k-th` | `/v1/images/generations` | `/v1/images/edits` |
| `gpt-image-2-adobe` | `/v1/images/generations` | 不开放 |
| `grok-imagine-image` | `/v1/images/generations` | `/v1/images/edits` |
| `nano-banana-2` | `/v1/responses` | `/v1/responses` |
| `nano-banana-pro` | `/v1/responses` | `/v1/responses` |

API 根地址固定为 `https://api.usegoodai.com`，鉴权使用 `Authorization: Bearer <API_KEY>`。脚本不得读取或覆盖 Codex 的 `auth.json`，也不得把 Key 写入请求记录、错误信息或生成图片目录。

### 参数转换

- `gpt-image-2` 使用 `size`、`quality` 和 `output_format`；默认 `1024x1024`、`high`、`png`。
- `gpt-image-1k-th` 使用 `1024x1024`，质量使用 `low` 或 `high`。
- `gpt-image-2-adobe` 使用 `1024x1536`、`1536x2304` 或 `2304x3456`，质量使用 `low`。
- `grok-imagine-image` 使用 `resolution`、`aspect_ratio` 和可选 `quality`，不要发送 GPT Image 的 `size`。

### Nano Banana 2 的调用方法和已验证参数

下面的内容只针对 `nano-banana-2`，写的是当前已用真实上游请求验证过的调用方式。文生图、参考图和改图都使用同一个 Responses 接口，不使用 Images 接口。

#### 1. 请求地址和请求头

```text
请求方法：POST
完整地址：https://api.usegoodai.com/v1/responses
```

请求头必须包含：

```http
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

`<API_KEY>` 替换成 UseGoodAI API Key。不要把 Key 写进请求体、日志、错误信息或输出文件。

#### 2. 文生图最小请求体

文本描述放在 `input[0].content` 中的 `input_text.text`，不能写成顶层 `prompt`：

```json
{
  "model": "nano-banana-2",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "一只红苹果放在白色桌面上"
        }
      ]
    }
  ],
  "stream": false,
  "response_format": {
    "type": "image",
    "mime_type": "image/png",
    "aspect_ratio": "1:1",
    "image_size": "1K"
  }
}
```

字段说明：

| 字段 | 必填 | 写法 |
| --- | --- | --- |
| `model` | 是 | 固定写 `nano-banana-2` |
| `input` | 是 | 数组，当前使用一个 `role: "user"` 对象 |
| `input[0].role` | 是 | 固定写 `user` |
| `input[0].content` | 是 | 文本、参考图和改图内容都放在这里 |
| `content[].type` | 是 | 文本使用 `input_text`，图片使用 `input_image` |
| `content[].text` | 文本请求时必填 | 完整图片描述或修改指令 |
| `stream` | 是 | 固定写 `false` |
| `response_format.type` | 是 | 固定写 `image` |
| `response_format.mime_type` | 是 | 当前固定写 `image/png` |
| `response_format.aspect_ratio` | 是 | 填已验证的比例，例如 `1:1` |
| `response_format.image_size` | 是 | 填 `512`、`1K`、`2K` 或 `4K` |

#### 3. 尺寸和比例

已验证的 `image_size`：

```text
512、1K、2K、4K
```

已验证的 `aspect_ratio`：

```text
1:1、3:2、2:3、3:4、1:4、4:1、4:3、4:5、
5:4、1:8、8:1、9:16、16:9、21:9、9:21
```

分辨率测试是在 `1:1` 下完成的，比例测试是在 `1K` 下完成的。因此，上面的结果表示这些尺寸和比例分别被上游接受，不表示每一个尺寸和每一个比例的组合都已经逐项测试。

本地工具命令中的 `--resolution 1k` 会转换为请求体中的 `"image_size": "1K"`；`512` 保持为 `"512"`。Nano Banana 不使用 `size`、`quality` 或 `output_format`，不要把这些字段加入请求体。

#### 4. 传一张参考图

参考图不是单独的上传接口，也不是把本地文件路径直接放进 JSON。调用脚本时按下面步骤处理：

1. 读取本地图片的二进制内容。
2. 判断图片格式，只接受 PNG、JPEG 或 WebP。
3. 使用标准 Base64 编码图片内容。
4. 拼成 Data URL：`data:<MIME 类型>;base64,<Base64 内容>`。
5. 在同一个 `content` 数组中加入一个 `input_image` 对象。

一张 PNG 参考图的请求体结构如下：

```json
{
  "model": "nano-banana-2",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "参考这张图片，生成一张白色背景的商品图，保留主体。"
        },
        {
          "type": "input_image",
          "image_url": "data:image/png;base64,<图片的Base64内容>"
        }
      ]
    }
  ],
  "stream": false,
  "response_format": {
    "type": "image",
    "mime_type": "image/png",
    "aspect_ratio": "1:1",
    "image_size": "1K"
  }
}
```

不同格式只替换 Data URL 的 MIME 类型：

```text
PNG：data:image/png;base64,<...>
JPEG：data:image/jpeg;base64,<...>
WebP：data:image/webp;base64,<...>
```

PNG、JPEG、WebP 单张参考图均已验证成功。

#### 5. 传两张或四张参考图

多张参考图仍然使用同一个 `content` 数组。每张图片各占一个独立的 `input_image` 对象，不能把多张图片拼成一个字符串，也不能增加 `images` 字段：

```json
{
  "model": "nano-banana-2",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "参考下面四张图片，综合它们的主要视觉特征，生成一张新的图片。"
        },
        {
          "type": "input_image",
          "image_url": "data:image/png;base64,<第1张图片>"
        },
        {
          "type": "input_image",
          "image_url": "data:image/jpeg;base64,<第2张图片>"
        },
        {
          "type": "input_image",
          "image_url": "data:image/webp;base64,<第3张图片>"
        },
        {
          "type": "input_image",
          "image_url": "data:image/png;base64,<第4张图片>"
        }
      ]
    }
  ],
  "stream": false,
  "response_format": {
    "type": "image",
    "mime_type": "image/png",
    "aspect_ratio": "1:1",
    "image_size": "1K"
  }
}
```

2 张不同参考图和 4 张不同参考图放在同一个请求中均已验证成功。14 张参考图的请求曾返回上游 `HTTP 502`，因此文档不把 14 张写成已支持，也不把它写成明确不支持。

#### 6. 改图

Nano Banana 改图不使用另一个接口，仍然调用：

```text
POST https://api.usegoodai.com/v1/responses
```

改图和参考图的请求结构相同，区别只在 `input_text.text` 的任务指令。把需要修改的原图作为 `input_image` 传入：

```json
{
  "model": "nano-banana-2",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "把背景改成纯红色，保留主体和构图不变。"
        },
        {
          "type": "input_image",
          "image_url": "data:image/png;base64,<原图的Base64内容>"
        }
      ]
    }
  ],
  "stream": false,
  "response_format": {
    "type": "image",
    "mime_type": "image/png",
    "aspect_ratio": "1:1",
    "image_size": "1K"
  }
}
```

上面的“改背景”请求已经验证成功，返回结果中背景变为纯红色，主体和构图基本保留。需要改图时，提示词必须明确写出“改什么”和“保留什么”。

#### 7. 一次生成多张

Responses 请求体不发送顶层 `n`。工具收到数量要求时，会按数量发送多个独立请求，每个请求只生成一张：

```text
用户要求生成 3 张
实际发送：3 个 POST /v1/responses 请求
每个请求：不包含 n，每个返回 1 张图片
```

`n=3` 已完成真实测试并成功返回 3 张图片。脚本不能把 `n` 直接塞进 Nano Banana 的请求体，也不能因为一次失败就自动重试或更换模型。

#### 8. 响应解析和保存

收到 HTTP 2xx 后，脚本只解析 Responses 返回 JSON 的 `output` 字段，提取其中的结构化图片 Base64、Data URL 或 HTTPS 图片地址。不要按 Images 接口的 `data[].b64_json` 结构解析 Nano Banana。

保存前必须确认：

1. 图片内容非空。
2. 图片文件签名有效。
3. 按实际格式保存为 PNG 或 JPEG 等正确扩展名。

输出目录使用当前项目的 `images`；没有项目时使用桌面的 `images`。只保存最终图片，不保存请求体、响应体、Base64 文本或 API Key。

### 解析和保存

1. Images 响应检查 `data[].b64_json` 和 `data[].url`；URL 只下载一次。
2. Responses 只扫描 `output`，解析结构化图片、Markdown Data URL 或 HTTPS 图片链接。
3. 只有图片字节非空且文件签名有效时才算成功，扩展名按照实际 PNG 或 JPEG 内容决定。
4. 输出目录使用当前项目的 `images`；没有项目时使用桌面的 `images`。
5. 只保留最终图片，不创建请求、响应、摘要或图片专属子目录。
6. 单图向 Codex 返回 `output_file`，多图返回 `output_files`；Codex 必须逐张调用 `view_image`。
7. `view_image` 成功后，最终回复必须用每张图片的绝对路径和 Markdown 图片语法再次嵌入全部图片；普通路径和普通文件链接不能代替图片嵌入。
8. HTTP 非 2xx、解码失败或保存失败时立即停止，不自动重试、不更换模型。

写入当前项目 `AGENTS.md` 的规则必须包含：固定使用本项目的 `生成图片.py`；模型只能从上表选择；每次调用前说明模型；不读取或显示 Key；失败不重试；成功后逐张调用 `view_image`，并在最终回复中用绝对路径 Markdown 图片语法再次嵌入所有成功图片。

</details>
