---
title: 安装生图工具
---

# 安装生图工具

安装后在 Codex 里说“画一张……”，Codex 会调用 UseGoodAI 的图片模型生成或修改图片，并直接显示在对话中。需要先完成 [快速开始](/quick-start)。

## 1. 创建专门画图分组的 API Key

在管理后台 **API 密钥** 页面另建一个 Key，名称写“画图专用”，分组选 **专门画图分组**，创建后复制。这个 Key 只给生图工具用，不是 Codex 对话用的 Key，两个不要复制反。

<details>
<summary>查看分组截图</summary>

<a class="doc-image-link" href="/images/画图/画图专用分组.jpg" target="_blank" rel="noopener">
  <img src="/images/画图/画图专用分组.jpg" alt="在 API 密钥页面核对专门画图分组并复制画图专用 API Key">
</a>

</details>

## 2. 安装生图工具

Windows 按 `Win + X`，点击 **终端** 或 **Windows PowerShell**；Mac 和 Linux 打开 **终端**。粘贴对应命令运行：

::: code-group

```powershell [Windows]
irm https://docs.usegoodai.com/install/usegoodai-imagines-tool/install.ps1 | iex
```

```bash [Mac / Linux]
curl -fsSL https://docs.usegoodai.com/install/usegoodai-imagines-tool/install.sh | bash
```

:::

看到“请输入专门画图分组 Key”时，粘贴第 1 步复制的 Key，按回车。支持 x64 Windows、x64 Linux 和 Mac（Apple 芯片和 Intel 芯片）。

<details>
<summary>不想用 PowerShell？</summary>

加入 <span style="color: #d93025;"><strong>QQ 群：1020015031</strong></span>，在群文件下载运行版，解压后双击 `UseGoodAI生图工具.exe`，按提示粘贴**专门画图分组 Key**。

</details>

## 3. 打开 Codex 开始生图

新建任务（Codex 已经打开时不用退出），发送 `画一张白底红苹果`。图片会直接显示在对话中。

<details>
<summary>查看常用说法</summary>

```text
画一张雨后城市街道的人物照片，电影感，自然光影，不要文字和水印。
```

```text
参考当前文件夹里的产品照片，生成一张白底电商主图。
```

```text
把这张图片的背景改成浅灰色，保留主体不变。
```

```text
用 nano-banana-2 按同一个要求生成 3 张图片。
```

</details>

<details>
<summary>查看支持的模型</summary>

| 模型 | 什么时候用 |
| --- | --- |
| `gpt-image-2.5-flare` | 默认模型，普通生图、修图和批量，输出 2K |
| `gpt-image-2.5-sunburst` | 说“高清”“精修”“重要成品”时自动使用，输出 2K |
| `gpt-image-2` | 指定时使用 |
| `gpt-image-1k-th` | 低成本 1K 方图，适合草图 |
| `gpt-image-2-adobe` | 2:3 竖图，只能文生图 |
| `grok-imagine-image` | 快速创意出图，输出尺寸固定 |
| `nano-banana-2` | 需要特殊比例，例如 4:1、1:8 |
| `nano-banana-pro` | 复杂画面和细节，当前只输出 1024x1024 |

用其它模型时，在说法里写模型名。尺寸和参数看 [生图参数汇总](/images/params)，价格看 [模型价格](/models)。

</details>

<details>
<summary>更新、卸载和文件位置</summary>

更新：对 Codex 说“更新生图工具”，按提示运行命令，重新粘贴专门画图分组 Key。双击版从群文件下载最新安装包重新运行。

卸载：对 Codex 说“卸载中转站生图工具”。专门画图 Key 默认保留，永久删除前会单独确认。

生成的图片保存在当前项目的 `images` 文件夹；没有打开项目时保存在桌面的 `images` 文件夹。

安装器写入这三处（Windows 在 `C:\Users\你的用户名\.codex\`，Mac 和 Linux 在 `~/.codex/`）：

| 位置 | 内容 |
| --- | --- |
| `tools/usegoodai-imagines-tool/` | 工具程序和专门画图 Key |
| `skills/usegoodai-image-generation/` | 生图 Skill |
| `AGENTS.md` | 追加生图规则，不改动原有内容 |

</details>

## 安装或生图失败

| 遇到的问题 | 处理方法 |
| --- | --- |
| 安装器提示 Key 无效，或生图返回鉴权错误 | 在 **API 密钥** 页面复制 **专门画图分组** 的 Key，重新运行第 2 步命令 |
| Codex 只回复图片路径，没有显示图片 | 对 Codex 说“把图片直接显示在对话里” |
| 生图接口返回错误 | 工具不会自动重试或换模型，稍后重新发一次 |
| 图片无法保存 | 在 Codex 里打开一个有写入权限的项目文件夹后再试 |

<details>
<summary>不用一键安装：让 Codex 创建 Python 脚本</summary>

脚本和规则只放在当前项目，只对当前项目生效，不安装全局 Skill。把下面整段发给 Codex：

```text
请完整阅读下面两个页面，严格按照操作：
https://docs.usegoodai.com/image-video-group-image.html （“自建脚本规则”）
https://docs.usegoodai.com/images/params.html （各模型接口和参数）

完成以下任务：
1. 在当前文件夹创建一个可运行的单文件生图脚本，文件名为“生成图片.py”。
2. 创建或更新当前项目根目录的 AGENTS.md，保留原有内容，写入“自建脚本规则”中的“项目生图规则”。
3. 除“生成图片.py”和 AGENTS.md 外，不创建其它文件，不自动安装依赖。
4. 为 UseGoodAI API Key 保留一个明显的配置项，创建完成后只让我填写这个值。
5. 脚本由 Codex 调用，每次接收完整图片描述、模型、数量、规格和可选原图文件，不把图片描述写死。
6. 模型选择顺序固定为：用户明确指定模型时使用该模型；未指定模型且明确要求高清、高质量、精细细节、精修、严格保留原图或重要成品时使用 gpt-image-2.5-sunburst；其余未指定模型的任务默认使用 gpt-image-2.5-flare。
7. 多图按张拆成独立的单张请求，每张只发送一次，禁止自动重试或静默更换模型。
8. 成功后最终回复用绝对路径 Markdown 图片语法嵌入每张图片，例如 `![生成结果](/absolute/path/image.png)`，不得只回复文件路径或普通链接。失败时显示脱敏错误，不创建空图片。
```

以后在这个项目里直接对 Codex 说“画一张……”即可。

#### 自建脚本规则

1. API Key 填 **专门画图分组** 的 Key。不读取或覆盖 Codex 的 `auth.json`，Key 不写进记录、错误信息或图片目录。
2. 接口、参数和返回图片的读取方法按 [生图参数汇总](/images/params)。
3. 图片保存到当前项目的 `images` 文件夹；没有项目时保存到桌面的 `images` 文件夹。只保留最终图片，不保存请求、响应或摘要文件。
4. 单图向 Codex 返回 `output_file`，多图返回 `output_files`。
5. HTTP 非 2xx、解码失败或保存失败时立即停止，不自动重试、不换模型。

项目生图规则（写入当前项目 `AGENTS.md`）：固定使用本项目的 `生成图片.py`；模型只能从生图参数汇总里选择；每次调用前说明使用的模型；不读取或显示 Key；失败不重试；成功后直接用绝对路径 Markdown 图片语法嵌入所有成功图片，不再调用 `view_image` 重新读取。

</details>
