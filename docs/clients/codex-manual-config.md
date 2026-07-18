# Codex 手动接入

CC Switch 无法导入时，按本文把 UseGoodAI 后台提供的 `config.toml` 和 `auth.json` 写入本机 `.codex` 文件夹。重新打开 Codex 后，即可通过 UseGoodAI 使用模型。

先按 [快速开始](/quick-start#第一步创建-api-key) 创建 API Key，再回来继续。

## 找到配置文件

Codex 的配置文件放在用户目录下的 `.codex` 文件夹中：

| 系统 | 配置目录 |
| --- | --- |
| Windows | `C:\Users\你的用户名\.codex`，也可以在文件管理器地址栏输入 `%USERPROFILE%\.codex` |
| macOS / Linux / WSL | `~/.codex` |

这个目录里需要处理两个文件：

| 文件 | 写入内容 |
| --- | --- |
| `config.toml` | 后台提供的模型、接口地址和接入配置 |
| `auth.json` | 后台提供的 UseGoodAI API Key 配置 |

### Windows：打开 `.codex` 文件夹

1. 打开 **此电脑**，进入 **本地磁盘 (C:)**，再打开 **用户** 文件夹。

<a class="doc-image-link" href="/images/连接/c盘1.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘1.jpg" alt="在 Windows 的 C 盘打开用户文件夹">
</a>

2. 打开你的 Windows 用户名文件夹。不要打开 **公用** 或 `Administrator`；图中的 `ss` 只是示例用户名。

<a class="doc-image-link" href="/images/连接/c盘2.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘2.jpg" alt="在用户文件夹中打开自己的 Windows 用户名">
</a>

3. 打开 `.codex` 文件夹。

<a class="doc-image-link" href="/images/连接/c盘3.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘3.jpg" alt="在 Windows 用户目录中打开 .codex 文件夹">
</a>

4. 找到 `auth.json` 和 `config.toml`。不要删除这个文件夹里的其它文件或文件夹。

<a class="doc-image-link" href="/images/连接/c盘4.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘4.jpg" alt="在 .codex 文件夹中找到 auth.json 和 config.toml">
</a>

文件不存在时，在 `.codex` 文件夹中新建同名文件。Windows 新建后确认文件名没有变成 `config.toml.txt` 或 `auth.json.txt`。

## 写入后台配置

回到 UseGoodAI 后台的 **API 密钥** 页面，在密钥列表中找到要使用的 Key，点击右侧的 **使用密钥**。

<a class="doc-image-link" href="/images/quick-start/create-api-key-3.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-3.jpg" alt="在 API 密钥列表中点击使用密钥">
</a>

在弹窗中选择 **Codex CLI**，再按本机系统选择 `macOS / Linux` 或 `Windows`。后台显示的是两段配置内容，不是两个下载文件。

1. 打开本机的 `config.toml`，删除里面原有的全部文字。把后台显示的 `config.toml` 内容粘贴进去并保存。
2. 打开本机的 `auth.json`，删除里面原有的全部文字。把后台显示的 `auth.json` 内容粘贴进去并保存。

两个文件不能贴反，也不要把两段内容合并到同一个文件。

<a class="doc-image-link" href="/images/quick-start/create-api-key-4.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-4.jpg" alt="复制 config.toml 和 auth.json 内容并分别保存">
</a>

## 重开 Codex 测试

Codex CLI 用户关闭原来的终端，重新打开终端后执行：

```bash
codex
```

ChatGPT 桌面应用用户先在右下角托盘找到 ChatGPT 图标，点击 **Exit** 彻底退出，再重新打开应用并切换到 Codex。仍未读取新配置时，在任务管理器中结束所有 ChatGPT 相关进程，或者重启电脑后再打开。

<a class="doc-image-link" href="/images/连接/c盘5.jpg" target="_blank" rel="noopener">
  <img src="/images/连接/c盘5.jpg" alt="从 Windows 右下角托盘退出 ChatGPT 桌面应用">
</a>

重新打开后，新建一个对话或任务，不要继续使用修改配置前的旧对话。发送：

```text
测试
```

能正常收到回复，就说明 Codex 已经通过 UseGoodAI 接入。需要核对实际请求时，进入 UseGoodAI 后台的 **使用记录** 页面查看。

## 常见问题

| 现象 | 检查动作 |
| --- | --- |
| `401 Unauthorized` | 重新复制后台的 `auth.json` 内容，确认 API Key 没有缺少字符 |
| `403 Forbidden` | 回到 **API 密钥** 页面，确认当前 Key 所属分组支持配置中的模型 |
| Windows 修改后不生效 | 确认文件名不是 `config.toml.txt` 或 `auth.json.txt`，再彻底退出并重新打开 Codex |
| 后台没有使用记录 | 确认两个文件位于当前 Codex 实际读取的 `.codex` 目录，并重新新建对话测试 |

仍然无法使用时，返回 [快速开始](/quick-start) 改用 CC Switch 一键导入。
