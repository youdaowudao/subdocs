# 保留 ChatGPT 登录

CC Switch 是图形化配置切换工具，这里用它打开 ChatGPT 桌面应用的 Codex 保持登录开关。已经安装 ChatGPT 桌面应用、并且有 ChatGPT 账号时，按本文操作；配置完成后，Codex 请求通过 UseGoodAI 发出，同时保留 ChatGPT 登录状态、插件入口和手机连接。本文主路径不需要手动修改文件；只有展开后面的旧方法时，才修改 `config.toml` 和 `auth.json`。

::: warning 重要提示
配置后，原 ChatGPT 账号的 Codex 对话记录默认不会显示在 app 上（本地文件还在）。在 CC Switch 设置中打开 **统一 Codex 会话历史** 可以显示历史列表，但基本无法继续原来的旧对话。需要保留记录时，请提前备份或连接后让 AI 整理。
:::

## 用 CC Switch 保留登录

还没有安装 CC Switch 时，先按 [Codex CC Switch 接入](/codex-cc-switch) 的第 1 步安装，安装完成后回到本页继续。

1. 打开 CC Switch，点击左上角的配置图标。

<a class="doc-image-link" href="/images/ccswitch/cc保持登陆1.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/cc保持登陆1.jpg" alt="在 CC Switch 左上角点击配置图标">
</a>

2. 进入 **通用** 设置，打开 **非接管切换时保留官方登录**。
3. 需要保留原 ChatGPT 账号的 Codex 会话列表时，再打开 **统一 Codex 会话历史**；这个开关基本无法继续原来的旧对话。

<a class="doc-image-link" href="/images/ccswitch/cc保持登陆2.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/cc保持登陆2.jpg" alt="在 CC Switch 通用设置中打开保留官方登录开关">
</a>

4. 完成设置后，回到 [Codex CC Switch 接入](/codex-cc-switch#_2-从管理后台导入配置)，从第 2 步“从管理后台导入配置”继续导入 UseGoodAI。

不需要手动修改 `config.toml` 和 `auth.json` 的用户，到这里就结束；直接回到上面的 CC Switch 导入页面，不要展开下面两种旧方法。

下面两种旧方法只给不能使用 CC Switch 的用户，任选一种。

<details>
<summary>懒人方法：复制给 AI 帮你改</summary>

先按 [快速开始](/quick-start) 创建 UseGoodAI API Key；已经有 Key 时直接继续。把下面这段话复制给能操作本机文件的 AI。AI 改完后，打开它给出的 `auth.json` 路径，只把 `OPENAI_API_KEY` 里的内容换成自己的 API Key 并保存。

```text
请帮我修改当前电脑上 ChatGPT 桌面应用中 Codex 的配置文件。

请先判断我当前使用的系统和 Codex 实际运行环境，再选择正确的 .codex 位置：
- Windows ChatGPT 桌面应用中的 Codex / PowerShell / CMD：C:\Users\我的用户名\.codex
- macOS / Linux / WSL：~/.codex

找不到 config.toml 或 auth.json 时，在对应位置新建。

要求：
1. 先备份旧 config.toml 和 auth.json。
2. 删除旧的模型端点配置：model_provider、[model_providers.xxx]、base_url。
3. 保留 MCP、插件、项目权限、工作区信任等无关配置。
4. 把下面的 config.toml 内容放到文件开头；如果原文件已有 [features]，把 goals 和 image_generation 合并进去，不要写两个 [features]。
5. 把下面的 auth.json 内容写入 auth.json，只把 OPENAI_API_KEY 的值换成我的 UseGoodAI API Key。
6. 不要退出 ChatGPT 登录。
7. 在回复结尾单独写出这次实际修改的 config.toml 和 auth.json 完整路径，提醒我检查 auth.json 里的 API Key。
8. 我填好 API Key 并保存后，再按下面方式测试：
   - 能运行 codex --version 时，执行：codex exec --skip-git-repo-check "测试"
   - macOS 找不到 codex 命令时，检查 /Applications/Codex.app/Contents/Resources/codex --version；存在就用这个路径执行同样测试。
   - 找不到可用命令时，不要安装 CLI；提醒我重启 ChatGPT 桌面应用，切换到 Codex 后新开对话并发送同一句测试消息，不要用旧对话。

config.toml 内容：

model_provider = "OpenAI"
model = "gpt-5.6-sol"
review_model = "gpt-5.6-sol"
model_reasoning_effort = "high"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.OpenAI]
name = "OpenAI"
base_url = "https://api.usegoodai.com"
wire_api = "responses"
requires_openai_auth = false
http_headers = { "x-openai-actor-authorization" = "local-image-extension" }

[features]
goals = true
image_generation = true

auth.json 内容：

{
  "OPENAI_API_KEY": "这里完整填写你的中转站 API Key"
}
```

`model` 和 `review_model` 要填当前 Key 分组里的模型名。默认示例使用 `gpt-5.6-sol`，两处保持一致。

</details>

<details>
<summary>手动方法：自己修改 config.toml 和 auth.json</summary>

1. 打开 ChatGPT 桌面应用，确认已经登录 ChatGPT，不要点退出登录。在左上角切换到 **ChatGPT Codex**。
2. 按当前运行环境打开 `.codex` 文件夹；没有对应文件时新建：

| 运行环境 | `.codex` 文件夹位置 |
| --- | --- |
| Windows ChatGPT 桌面应用中的 Codex / PowerShell / CMD | `C:\Users\你的用户名\.codex` |
| macOS / Linux / WSL | `~/.codex` |

3. 修改前先复制一份旧的 `config.toml` 和 `auth.json` 作为备份。
4. 打开 `config.toml`，删除旧的模型端点配置，保留下面这套 Sub2api 推荐的 OpenAI 配置。
5. 保留文件下方已有的 MCP、插件、项目权限、工作区等其它配置。
6. 保存前检查全文不要出现重复的 `[model_providers.OpenAI]` 或两个 `[features]`。

```toml
model_provider = "OpenAI"
model = "gpt-5.6-sol"
review_model = "gpt-5.6-sol"
model_reasoning_effort = "high"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.OpenAI]
name = "OpenAI"
base_url = "https://api.usegoodai.com"
wire_api = "responses"
requires_openai_auth = false
http_headers = { "x-openai-actor-authorization" = "local-image-extension" }

[features]
goals = true
image_generation = true
```

7. 打开 `auth.json`，写入下面内容，只把 `OPENAI_API_KEY` 里的内容换成自己的 UseGoodAI API Key。

```json
{
  "OPENAI_API_KEY": "这里完整填写你的中转站 API Key"
}
```

8. 完全退出 ChatGPT 桌面应用，再重新打开并切换到 Codex。

进入 ChatGPT 桌面应用的 Codex 后，新开对话或任务，不要继续旧对话。先发一句普通测试：

```text
测试
```

能正常回复，并且 UseGoodAI 后台使用记录页面有调用记录，就说明配置完成。记录里的模型、分组和计费要符合预期；分组不对时到 API 密钥页面改 Key 分组，模型不对时改 `config.toml` 里的 `model` / `review_model`，计费有疑问时联系客服。

需要测试 Codex 内置生图时，继续看 [Codex 内置生图](/images/codex-image-direct)。

### 手机连接

ChatGPT 桌面应用中的 Codex 保持 ChatGPT 登录后，手机端可以在 ChatGPT 的 **Remote** 标签查看受支持的桌面任务。电脑端连接设置仍按图中三个箭头操作：

<a class="doc-image-link" href="/images/连接/手机连接.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/手机连接.jpg" alt="ChatGPT 桌面应用中 Codex 的连接设置和手机扫码入口">
</a>

1. 左侧点击 **连接**。
2. 在 **控制此电脑** 页面点击 **添加**。
3. 手机端登录 ChatGPT 后扫描二维码。
4. 长期使用时，打开 **使此电脑保持唤醒**。
5. 不再使用某台设备时，在设备列表里点击 **撤销访问权限**。

### 常见问题

| 问题 | 处理方式 |
| --- | --- |
| 修改配置后没有生效 | 保存配置后完全退出 ChatGPT 桌面应用，再重新打开并切换到 Codex。 |
| 配置后 Codex 打不开或无法运行 | 检查 `config.toml` 里是否写了两个 `[features]`；有两个就合并成一个。 |
| 能写代码，但不能生图 | 进入 [Codex 内置生图](/images/codex-image-direct)，按生图页修改 `config.toml`。 |
| 请求没有到达 UseGoodAI | 检查 `base_url` 是否为 `https://api.usegoodai.com`，`auth.json` 里的 API Key 是否复制完整。 |
| 手机端连不上 | 回到 **连接** 页面重新点击 **添加**，手机端登录 ChatGPT 后重新扫码。 |

</details>
