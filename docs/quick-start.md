# 快速开始

本文适合第一次使用 UseGoodAI 的用户。按本文做完后，Codex CLI 或 Codex App 会使用本中转站的 API Key 发起请求。

你只需要完成两件事：在后台创建 API Key；把后台生成的 Codex 配置复制到本机 `.codex` 目录里的 `config.toml` 和 `auth.json`。

看不懂某一步时，把截图发给豆包、DeepSeek 等 AI 工具，让它用更简单的话解释当前步骤。

## 第一步：进入 API 密钥页面

登录 UseGoodAI 后台，左侧进入 **API 密钥**，然后点击 **创建密钥**。

<a class="doc-image-link" href="/images/quick-start/create-api-key-1.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-1.jpg" alt="进入 API 密钥页面并点击创建密钥">
</a>

## 第二步：填写名称并选择分组

名称写成能看懂用途的名字，例如 `编程专用`。

分组必须认真选择。这个分组决定这个 API Key 能不能使用你要接入的模型；分组选错，后面即使 Key 填对，也会无法调用。

<a class="doc-image-link" href="/images/quick-start/create-api-key-2.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-2.jpg" alt="填写密钥名称并选择正确分组">
</a>

::: warning
除名称和分组外，其它限制项保持默认。
:::

## 第三步：打开后台生成配置

创建成功后，在密钥列表里找到刚才创建的 Key，点击右侧的 **使用密钥**。

后续遇到 403 或模型不可用，回到这里确认分组是否选对。

<a class="doc-image-link" href="/images/quick-start/create-api-key-3.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-3.jpg" alt="创建成功后点击使用密钥">
</a>

## 第四步：复制并保存 Codex 配置

Codex 的配置文件放在用户目录下的 `.codex` 文件夹中。

Windows 有两种打开方式。

第一种：按 `Win + R`，输入：

```text
%userprofile%\.codex
```

第二种：打开 C 盘，依次进入：

```text
C:\Users\你的用户名\.codex
```

macOS / Linux / WSL 路径是：

```text
~/.codex
```

目录不存在就手动创建一个。

你需要在这个目录里处理两个文件：

| 文件 | 用途 |
| --- | --- |
| `config.toml` | 保存模型、接口地址、接入方式等配置 |
| `auth.json` | 保存 API Key |

在后台弹窗里选择 **Codex CLI**，再按你的系统选择 `macOS / Linux` 或 `Windows`。Codex App 也读取这份本机 `.codex` 配置。

后台会分别给出 `config.toml` 和 `auth.json` 需要复制的内容。点击复制，把 `config.toml` 内容粘贴到本机的 `config.toml`，把 `auth.json` 内容粘贴到本机的 `auth.json`，然后保存。

<a class="doc-image-link" href="/images/quick-start/create-api-key-4.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-4.jpg" alt="复制 Codex CLI 配置和 API Key">
</a>

## 第五步：启动 Codex 测试

Codex CLI 用户重新打开一个终端，执行：

```bash
codex
```

Codex App 用户重新打开 App 后新建一个对话或任务。
桌面版没有读取新配置时，彻底退出 Codex App 后再重新打开；Windows 用户从任务管理器结束相关进程。

进入 Codex 后，发送一句测试：

```text
测试
```

能正常收到回复，就说明本机 Codex 已经通过 UseGoodAI 接入成功。

## 第六步：回到后台确认记录

测试完成后，回到 UseGoodAI 后台的 **使用记录** 页面，确认刚才创建的 Key 有调用记录。

同时核对三项：

| 要核对什么 | 不对时怎么处理 |
| --- | --- |
| 模型 | 回到 Codex 修改配置里的模型名 |
| 分组 | 回到 **API 密钥** 页面修改这个 Key 的分组 |
| 计费 | 对费用有疑问时，联系客服核对 |

## 常见问题

| 现象 | 先检查这里 |
| --- | --- |
| `codex` 命令不存在 | App 用户跳过这一项；CLI 用户重新检查 Codex 安装。 |
| 401 / Unauthorized | `auth.json` 里的 API Key 是否复制完整 |
| 403 / Forbidden | API Key 选择的分组是否支持当前模型 |
| 429 / Too Many Requests | 先看账户余额；账户有余额时，再检查这个 API Key 是否设置了限额金额、速率或次数限制 |
| 模型不可用 | 模型名和 Key 所属分组是否匹配 |
| 后台没有调用记录 | `config.toml` 和 `auth.json` 是否放在正确的 `.codex` 目录 |
| Windows 配置不生效 | 文件名不要变成 `config.toml.txt` 或 `auth.json.txt` |

## 下一步

- 需要看 Codex 参数含义：进入 [Codex](/clients/codex)
- 需要保留 ChatGPT 登录、内置生图或手机连接：进入 [保持 ChatGPT 登录同时连接中转站](/chatgpt-login-usegoodai)
- 需要确认模型和分组：进入 [模型与分组](/models)
- 遇到 403：进入 [报错与踩坑](/errors/)
