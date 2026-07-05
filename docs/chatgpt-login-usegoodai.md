# 保持 ChatGPT 登录同时连接中转站

本文适合已经使用 Codex App 的用户。配置完成后，Codex App 继续保持 ChatGPT 登录状态，同时模型请求走 UseGoodAI 中转站。

配置后保留 Codex App 的内置生图、插件入口、手机端连接和其它设备连接。本文只修改本机 `config.toml`。

## 适合谁

| 你的目标 | 看哪里 |
| --- | --- |
| 第一次跑通 Codex | 先看 [快速开始](/quick-start) |
| 保留 ChatGPT 登录状态，同时让请求走中转站 | 看本文 |
| 只配置 Codex CLI，不用 App 内置能力 | 看 [Codex](/clients/codex) |

## 懒人方法：复制给 AI 帮你改

把下面这段话复制给能操作本机文件的 AI。最后只把 `experimental_bearer_token` 双引号里的内容换成自己的 API Key。

```text
请帮我修改当前电脑的 Codex 配置文件。

请先判断我当前使用的系统和 Codex 实际运行环境，再选择正确的 config.toml 位置：
- Windows Codex App / PowerShell / CMD：C:\Users\我的用户名\.codex\config.toml
- macOS / Linux / WSL：~/.codex/config.toml

找不到 config.toml 时，在对应位置新建。

要求：
1. 先备份旧 config.toml。
2. 删除旧的模型端点配置：model_provider、[model_providers.xxx]、base_url。
3. 保留 MCP、插件、项目权限、工作区信任等无关配置。
4. 把下面配置放到文件开头；如已有 [features]，合并进去，不要写两个。
5. 不要退出 ChatGPT 登录，不要删除 auth.json。
6. 改完提醒我只替换 experimental_bearer_token 里的 API Key。
7. 改完后测试：
   - 能运行 codex --version 时，执行：codex exec --skip-git-repo-check "测试"
   - macOS 找不到 codex 命令时，检查 /Applications/Codex.app/Contents/Resources/codex --version；存在就用这个路径执行同样测试。
   - 找不到可用命令时，不要安装 CLI；提醒我重启 Codex App，在 App 里发送同一句测试消息。

model_provider = "UseGoodAI"
model = "gpt-5.5"
review_model = "gpt-5.5"
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true

[model_providers.UseGoodAI]
name = "UseGoodAI"
base_url = "https://api.usegoodai.com/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "这里完整填写你的中转站 API Key"

[features]
image_generation = true
```

## 手动配置

1. 打开 Codex App，确认已经登录 ChatGPT，不要点退出登录。
2. 按当前运行环境打开 `config.toml`；没有就新建：

| 运行环境 | 配置文件位置 |
| --- | --- |
| Windows Codex App / PowerShell / CMD | `C:\Users\你的用户名\.codex\config.toml` |
| macOS / Linux / WSL | `~/.codex/config.toml` |

3. 修改前先复制一份旧的 `config.toml` 作为备份。
4. 删除旧的模型端点配置，保留本文这套 UseGoodAI 配置。
5. 保留文件下方已有的 MCP、插件、项目权限、工作区等其它配置。
6. 把上面的配置放到文件开头，只改 `experimental_bearer_token` 里的 API Key。
7. 原来已经有 `[features]` 时，把 `image_generation = true` 合并进去，不要重复创建第二个 `[features]`。
8. 保存文件。
9. 完全退出 Codex App，再重新打开。

## 验证

进入 Codex App 后，先发一句普通测试：

```text
测试
```

到 UseGoodAI 后台的使用记录页面确认有调用记录后，再测试内置生图：

```text
生成一张苹果图片。
```

能正常回复、使用记录页面有调用记录，并且内置生图可用，就说明配置完成。记录里的模型、分组和计费要符合预期；分组不对时到 API 密钥页面改 Key 分组，模型不对时改 `config.toml` 里的 `model` / `review_model`，计费有疑问时联系客服。

## 手机连接

Codex App 保持 ChatGPT 登录后，手机端或其它设备扫码连接这台电脑。按图中三个箭头操作：

<a class="doc-image-link" href="/images/连接/手机连接.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/手机连接.jpg" alt="Codex App 连接设置和手机扫码入口">
</a>

1. 左侧点击 **连接**。
2. 在 **控制此电脑** 页面点击 **添加**。
3. 手机端登录 ChatGPT 后扫描二维码。
4. 长期使用时，打开 **使此电脑保持唤醒**。
5. 不再使用某台设备时，在设备列表里点击 **撤销访问权限**。

## 常见问题

| 问题 | 处理方式 |
| --- | --- |
| 修改配置后没有生效 | 保存配置后完全退出 Codex App，再重新打开。 |
| 配置后 Codex 打不开或无法运行 | 检查 `config.toml` 里是否写了两个 `[features]`；有两个就合并成一个。 |
| 能写代码，但不能生图 | 检查 `[features]` 里是否写了 `image_generation = true`。 |
| 请求没有到达 UseGoodAI | 检查 `base_url` 是否为 `https://api.usegoodai.com/v1`，API Key 是否复制完整。 |
| 手机端连不上 | 回到 **连接** 页面重新点击 **添加**，手机端登录 ChatGPT 后重新扫码。 |
