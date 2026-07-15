# 快速开始

本文适合第一次使用 UseGoodAI 的用户。按本文做完后，Codex CLI 或 ChatGPT 桌面应用中的 Codex 会使用本中转站的 API Key 发起请求。

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

## 第三步：在本机找到两个配置文件

Codex 的配置文件放在用户目录下的 `.codex` 文件夹中。先找到这两个文件，下一步再回后台复制内容。

你需要在这个目录里处理两个文件：

| 文件 | 用途 |
| --- | --- |
| `config.toml` | 保存模型、接口地址、接入方式等配置 |
| `auth.json` | 保存 API Key |

### Windows：按文件夹打开 `.codex`

1. 打开 **此电脑**，进入 **本地磁盘 (C:)**，再打开 **用户** 文件夹。

<a class="doc-image-link" href="/images/连接/c盘1.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘1.jpg" alt="在 Windows 的 C 盘打开用户文件夹">
</a>

2. 打开你的 Windows 用户名文件夹。不要打开 **公用** 或 `Administrator`；图中的 `ss` 只是示例用户名。

<a class="doc-image-link" href="/images/连接/c盘2.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘2.jpg" alt="在用户文件夹中打开自己的 Windows 用户名">
</a>

3. 打开 `.codex` 文件夹。完整位置是 `C:\Users\你的用户名\.codex`。

<a class="doc-image-link" href="/images/连接/c盘3.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘3.jpg" alt="在 Windows 用户目录中打开 .codex 文件夹">
</a>

4. 在 `.codex` 文件夹中找到 `auth.json` 和 `config.toml`。不要删除其它文件或文件夹。

<a class="doc-image-link" href="/images/连接/c盘4.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘4.jpg" alt="在 .codex 文件夹中找到 auth.json 和 config.toml">
</a>

### macOS / Linux / WSL

配置目录是：

```text
~/.codex
```

两个文件不存在时，在 `.codex` 文件夹中新建同名文件。Windows 新建后确认文件名没有变成 `config.toml.txt` 或 `auth.json.txt`。

## 第四步：在 API 密钥页面复制并写入配置

回到 UseGoodAI 后台，左侧进入 **API 密钥**。在密钥列表里找到刚才创建的 Key，点击右侧的 **使用密钥**。

<a class="doc-image-link" href="/images/quick-start/create-api-key-3.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-3.jpg" alt="在 API 密钥列表中点击使用密钥">
</a>

在弹窗里选择 **Codex CLI**，再按你的系统选择 `macOS / Linux` 或 `Windows`。ChatGPT 桌面应用中的 Codex 也读取这份本机 `.codex` 配置。

### 分别写入两个文件

1. 复制后台给出的 `config.toml` 内容，粘贴到本机同名文件并保存。`config.toml` 里只能有一个 `[features]`；已有时，把后台配置里的功能项合并进去。
2. 复制后台给出的 `auth.json` 内容，粘贴到本机同名文件并保存。

<a class="doc-image-link" href="/images/quick-start/create-api-key-4.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-4.jpg" alt="复制 config.toml 和 auth.json 内容并分别保存">
</a>

## 第五步：启动 Codex 测试

Codex CLI 用户重新打开一个终端，执行：

```bash
codex
```

ChatGPT 桌面应用用户重新打开应用，切换到 Codex 后新建一个对话或任务，不要继续旧对话。

Windows 用户修改配置前已经打开 ChatGPT 桌面应用时，先在右下角托盘找到 ChatGPT 图标，点击 **Exit** 彻底退出，再重新打开应用。这样才能读取刚保存的配置。

<a class="doc-image-link" href="/images/连接/c盘5.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘5.jpg" alt="从 Windows 右下角托盘退出 ChatGPT 桌面应用">
</a>

进入新的 Codex 对话后，发送一句测试：

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
| Codex 打不开或配置报错 | `config.toml` 是否有两个 `[features]`；有两个就合并成一个 |
| Windows 配置不生效 | 文件名不要变成 `config.toml.txt` 或 `auth.json.txt` |

## 下一步

- 需要看 Codex 参数含义：进入 [Codex](/clients/codex)
- 需要保留 ChatGPT 登录、内置生图或手机连接：进入 [保持 ChatGPT 登录同时连接中转站](/chatgpt-login-usegoodai)
- 需要确认模型和分组：进入 [模型与分组](/models)
- 遇到 403：进入 [报错与踩坑](/errors/)
