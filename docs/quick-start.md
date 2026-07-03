# 快速开始：Codex 接入 UseGoodAI

这篇教程是给第一次使用 UseGoodAI 的用户看的。你不需要先理解 API、Base URL 或配置文件是什么意思，只要按下面的截图一步一步操作，就可以把 Codex CLI 或 Codex App 接到 UseGoodAI 上。

你要做的事情只有两件：先在 UseGoodAI 后台创建一个 API 密钥，再把后台自动生成的 Codex 配置复制到电脑里的配置文件中。Codex CLI 和 Codex App 使用的是同一个 Codex 配置。

::: tip
如果有看不明白的地方，可以截图发给豆包、DeepSeek 等 AI 工具，让它用更简单的话解释当前步骤。
:::

## 第一步：进入 API 密钥页面

登录 UseGoodAI 后台，左侧进入 **API 密钥**，然后点击 **创建密钥**。

<a class="doc-image-link" href="/images/quick-start/create-api-key-1.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-1.jpg" alt="进入 API 密钥页面并点击创建密钥">
</a>

## 第二步：填写名称并选择分组

名称可以随便写，建议写成能看懂用途的名字，例如 `编程专用`。

分组必须认真选择。这个分组决定这个 API Key 能不能使用你要接入的模型；分组选错，后面即使 Key 填对，也可能无法调用。

<a class="doc-image-link" href="/images/quick-start/create-api-key-2.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-2.jpg" alt="填写密钥名称并选择正确分组">
</a>

::: warning
除名称和分组外，其它限制项默认不要填写。限额金额是这个 API Key 的消费上限，不是账户余额；日期、速率、次数等限制项也是给特殊场景用的，普通接入保持默认即可。默认并发速率是 `20`，需要更高并发可以联系客服提升。
:::

## 第三步：打开 Codex 配置

创建成功后，在密钥列表里找到刚才创建的 Key，点击右侧的 **使用密钥**。

这里也可以看到这个 Key 的分组和用量统计。以后如果遇到 403 或模型不可用，优先回到这里确认分组是否选对。

<a class="doc-image-link" href="/images/quick-start/create-api-key-3.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-3.jpg" alt="创建成功后点击使用密钥">
</a>

## 第四步：复制并保存 Codex 配置

Codex 的配置文件放在用户目录下的 `.codex` 文件夹中。

Windows 可以按 `Win + R`，输入：

```text
%userprofile%\.codex
```

macOS / Linux 一般是：

```text
~/.codex
```

如果这个目录不存在，就手动创建一个。

你需要在这个目录里处理两个文件：

| 文件 | 用途 |
| --- | --- |
| `config.toml` | 保存模型、接口地址、接入方式等配置 |
| `auth.json` | 保存 API Key |

在后台弹窗里选择 **Codex CLI**。

然后按你的系统选择 `macOS / Linux` 或 `Windows`。

后台会分别给出 `config.toml` 和 `auth.json` 需要复制的内容。点击复制，把 `config.toml` 内容粘贴到本机的 `config.toml`，把 `auth.json` 内容粘贴到本机的 `auth.json`，然后保存。

<a class="doc-image-link" href="/images/quick-start/create-api-key-4.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-4.jpg" alt="复制 Codex CLI 配置和 API Key">
</a>

## 第五步：启动 Codex 测试

如果你使用 Codex CLI，重新打开一个终端，执行：

```bash
codex
```

如果你使用 Codex App，重新打开 App 后新建一个对话或任务即可。
如果桌面版没有读取新配置，先彻底退出 Codex App 后再重新打开；Windows 用户必要时可以在任务管理器中结束相关进程。

进入 Codex 后，可以先发一句测试：

```text
用一句话回复：UseGoodAI Codex 连接是否成功。
```

能正常收到回复，就说明本机 Codex 已经通过 UseGoodAI 接入成功。

## 第六步：回到后台确认用量

测试完成后，回到 UseGoodAI 后台的 API 密钥页面或使用记录页面，确认刚才创建的 Key 有调用记录或用量变化。

如果本机显示失败，但后台完全没有记录，通常说明本机配置没有生效，或者配置文件没有放到正确目录。

## 关于 `/v1`

Codex CLI 这类后台已经生成专用配置的场景，**优先使用后台复制出来的地址**，一般不需要自己额外加 `/v1`。

只有在外接普通 OpenAI-compatible 客户端时，如果客户端要求填写 OpenAI 风格的 `Base URL`，才可能需要填写：

```text
https://api.usegoodai.com/v1
```

简单判断：有后台生成配置就复制后台配置；没有生成配置、只能手动填 OpenAI-compatible 地址时，再考虑 `/v1`。

## 常见问题

| 现象 | 先检查这里 |
| --- | --- |
| `codex` 命令不存在 | 这是 Codex CLI 的问题；App 用户可以跳过这一项 |
| 401 / Unauthorized | `auth.json` 里的 API Key 是否复制完整 |
| 403 / Forbidden | API Key 选择的分组是否支持当前模型 |
| 429 / Too Many Requests | 先看账户余额；如果明明有余额，再检查这个 API Key 是否设置了限额金额、速率或次数限制 |
| 模型不可用 | 模型名和 Key 所属分组是否匹配 |
| 后台没有调用记录 | `config.toml` 和 `auth.json` 是否放在正确的 `.codex` 目录 |
| Windows 配置不生效 | 文件名不要变成 `config.toml.txt` 或 `auth.json.txt` |

## 下一步

- 需要看 Codex 参数含义：进入 [Codex CLI 接入](/clients/codex)
- 需要确认模型和分组：进入 [模型与分组](/models)
- 遇到 403：进入 [报错与踩坑](/errors/)
