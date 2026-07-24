---
title: 视频分组方法
---

# 视频分组方法（视频功能正在测试，敬请期待）

“生图与视频分组”提供 `Grok` 和 `Seedance` 视频模型。让 Codex 按本文创建调用脚本，并把生成的视频保存到本地。

需要生成图片时，进入[生图分组方法](/images/image-video-group-image)。

## 第一次使用：让 Codex 创建调用工具

把下面整段提示词发给 Codex：

```text
请完整阅读并严格按照这个页面操作：
https://docs.usegoodai.com/images/image-video-group-video.html

根据页面中的“Codex 必须遵守的调用规则”，完成以下任务：
1. 在当前文件夹创建一个可运行的单文件视频生成脚本，文件名为“生成视频.py”。
2. 创建或更新当前项目根目录的 AGENTS.md，保留原有内容，并写入页面规定的“项目视频规则”。
3. 除“生成视频.py”和 AGENTS.md 外，不创建其它工程文件，也不自动安装依赖。
4. 为 UseGoodAI API Key 保留一个明显的配置项，创建完成后只让我填写这个值。
5. 这个脚本是给 Codex 调用的，不要让我手动修改视频描述、模型或运行命令。
6. 脚本必须接收 Codex 每次传入的完整视频描述和模型，不能把视频描述写死在脚本里。
7. 视频模型价格较高。每次调用前必须先告诉我准备使用的模型并提醒费用，等我明确确认模型后才能发送请求。
8. 每次只发送一次视频生成请求，禁止自动批量调用或重试。
9. 成功后把视频下载到当前文件夹并告诉我本地文件位置；失败时原样显示错误并保留完整响应。
```

## 以后使用：直接告诉 Codex 要什么视频

配置一次 API Key 后，不再打开或修改脚本。直接在提示词中写明模型：

```text
使用 `grok-imagine-video-1.5-fast` 生成一段雨后城市街道的人物短视频，电影感，自然动作，不要文字和水印。调用前先告诉我模型并等待确认。
```

没有选定模型时，先对 Codex 说：

```text
先列出当前可用的视频模型并说明各自的速度或分辨率档位，不要立即生成。等我选定模型后再调用。
```

Codex 会在你确认模型后，把视频要求传给 `生成视频.py`，生成成功后返回保存在本地的视频文件。

::: danger 视频模型价格较高
视频生成的费用通常高于普通请求，具体价格查看[模型价格](/models)。每次生成前，先让 Codex 说明准备使用的模型并等待你确认；不要随意测试、批量调用或自动重试。
:::

## 让规则在当前项目长期生效

上面的提示词会让 Codex 把视频规则写入当前项目根目录的 `AGENTS.md`。以后从这个项目开始的新任务仍会读取这些规则；规则只对当前项目生效，不会修改其它项目或全局配置。

::: details Codex 必须遵守的调用规则

请求方法、地址和鉴权：

```text
POST https://api.usegoodai.com/v1/responses
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

## 支持的视频模型

所有视频模型都使用 `/v1/responses`。分辨率和速度档位直接通过模型名选择：

| 模型 | 说明 |
| --- | --- |
| `grok-imagine-video` | Grok 视频 |
| `grok-imagine-video-1.5-fast` | Grok 1.5 快速版，可作为未选模型时的推荐项 |
| `grok-imagine-video-1.5-preview` | Grok 1.5 Preview |
| `grok-imagine-video-1.5-preview-1080p` | Grok 1.5 Preview 1080p |
| `seedance-2.0-fast-480p` | Seedance 2.0 快速版 480p |
| `seedance-2.0-480p` | Seedance 2.0 480p |
| `seedance-2.0-fast-720p` | Seedance 2.0 快速版 720p |
| `seedance-2.0-720p` | Seedance 2.0 720p |
| `seedance-2.0-1080p` | Seedance 2.0 1080p |

Codex 必须按上表原样发送模型名，不自行拼接分辨率字段。

请求体使用下面的结构，把脚本收到的命令行参数写入 `text`：

```json
{
  "model": "<本次选择的模型>",
  "instructions": "只生成视频，不返回文字说明。",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "<运行脚本时收到的视频描述>"
        }
      ]
    }
  ],
  "stream": false,
  "store": false
}
```

脚本必须遵守以下规则：

1. 允许使用的模型只有上方表格列出的九个模型，不得改写模型名或静默替换模型。
2. 用户没有指定模型时，先列出模型；可以推荐 `grok-imagine-video-1.5-fast`，但不能自动调用。
3. 每次请求前，Codex 必须先说明准备使用的模型并提醒视频模型价格较高，等用户明确确认模型后才能调用脚本。
4. 每次运行只发送一次请求，不自动批量调用、不重试，也不自行改用其它接口。
5. 没有视频描述、没有确认模型或模型不在允许列表中时明确停止，不能使用脚本内置的默认提示词或其它模型。
6. 保存 HTTP 状态码、响应头和原始响应体。HTTP 非 2xx 时原样显示错误并停止，不创建空视频。
7. HTTP 2xx 时检查 `status` 是否为 `completed`，再从 `output[].content[].text` 或 `output_text` 中提取第一个有效的 `https://` 视频地址。
8. 视频地址只下载一次。下载成功且文件非空后保存到当前文件夹，再调用系统默认播放器打开。
9. 找不到视频地址或下载失败时，保留完整响应并明确报错，不创建空文件。

写入当前项目根目录 `AGENTS.md` 的“项目视频规则”必须包含：

```md
## 项目视频规则

- 本项目的视频任务统一调用当前项目内的 `生成视频.py`，请求 `POST https://api.usegoodai.com/v1/responses`。
- 可用模型只有 `grok-imagine-video`、`grok-imagine-video-1.5-fast`、`grok-imagine-video-1.5-preview`、`grok-imagine-video-1.5-preview-1080p`、`seedance-2.0-fast-480p`、`seedance-2.0-480p`、`seedance-2.0-fast-720p`、`seedance-2.0-720p`、`seedance-2.0-1080p`，不得静默替换模型。
- 视频模型价格较高。用户没有指定模型时先列出模型，可以推荐 `grok-imagine-video-1.5-fast`，但不能自动调用。
- 每次调用前先说明准备使用的模型并提醒费用，等用户明确确认模型后才能发送请求。视频描述和模型由 Codex 在本次调用时传给脚本，不写死在脚本中。
- 每次生成只发送一次请求，禁止自动批量调用或重试。失败时保留完整响应并原样报告错误。
- 生成成功后必须下载有效的本地视频并告诉用户文件位置。
```

:::
