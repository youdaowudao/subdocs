---
title: 给 Codex 导入国产模型
sidebarTitle: 导入国产模型
---

# 给 Codex 导入国产模型

这个脚本把 11 个国产模型加入 Codex 的模型列表，适合已经接入 UseGoodAI、希望在 GPT 和国产模型之间选择的用户。脚本自动更新用户目录中的 `.codex/config.toml` 和本地模型目录，保留原有 GPT、默认模型、接口和 Key。

## 一键导入

**Linux / macOS：打开终端，复制运行。**

```sh
curl -fsSL https://docs.usegoodai.com/install/codex-models.sh | sh
```

Linux 需要本机已有 Node.js 16 或以上版本。Linux / macOS 导入成功后会自动关闭 ChatGPT/Codex，正在运行的任务会中断。

**Windows：按 `Win + X`，打开终端或 Windows PowerShell，复制运行。**

<details>
<summary>找不到 PowerShell？</summary>

加入 <span style="color: #d93025;"><strong>QQ 群：1020015031</strong></span>，在群文件下载运行版，解压后双击 `Codex国产模型导入.exe` 即可。Mac 使用同名 `.app`。

</details>

```powershell
irm https://docs.usegoodai.com/install/codex-models.ps1 | iex
```

Windows 脚本只读写 `CODEX_HOME` 中的配置与模型文件；未设置时使用 `C:\Users\你的用户名\.codex`。完成后手动退出并重新打开 ChatGPT App。

## 重新打开 App 选择模型

在中转站把当前 API Key 切换到支持所选模型的分组，分组和模型 ID 见[模型价格](/models)。

重新打开 App，**新建任务**，在模型选择器中选择要用的国产模型，发送 `测试`。

<details>
<summary>查看本次导入的 11 个模型</summary>

| 厂商 | 模型 ID（按导入顺序） |
| --- | --- |
| DeepSeek | `deepseek-flash`、`deepseek-v4.1-flash-1017` |
| GLM | `glm-5.3`、`glm-5.3-flash` |
| Qwen 千问 | `qwen3.8-max`、`qwen3.8-flash` |
| Kimi | `kimi-k3` |
| MiniMax | `minimax-m3` |
| 腾讯混元 | `hy4-preview` |
| 小米 MiMo | `mimo-v2.6-pro`、`mimo-v2.6-flash` |

</details>

## 更新或卸载

**需要更新模型列表时，重新运行上面的命令。使用双击版时，先从群文件下载最新安装包，再运行国产模型导入工具。**

<details>
<summary>卸载导入的国产模型</summary>

Linux / macOS 打开终端运行：

```sh
curl -fsSL https://docs.usegoodai.com/install/codex-models.sh | sh -s -- --uninstall
```

Windows 打开 PowerShell 运行：

```powershell
& ([scriptblock]::Create((irm https://docs.usegoodai.com/install/codex-models.ps1))) -Uninstall
```

卸载只移除本工具导入的国产模型，保留 GPT、其他自定义模型、接口和 Key；本地模型目录继续保留其余模型。完成后按脚本提示重新打开 App，新建任务继续使用。

</details>
