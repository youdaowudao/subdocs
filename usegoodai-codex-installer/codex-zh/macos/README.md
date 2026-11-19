# Mac Codex 桌面版中文化

这个工具给 Mac 上官方 ChatGPT 应用里的 Codex 启用内置的界面翻译，并在 `~/.codex/config.toml` 把桌面语言设为简体中文。适合已安装官方桌面版、选择中文后仍显示英文的用户。

保存工作并结束正在运行的任务。在 Mac 的「终端」运行下面这条命令。电脑需要已有可用的 Python 3.9 或更新版本。

```sh
curl -fsSL https://docs.usegoodai.com/install/chinese.sh | /bin/bash
```

命令会关闭并重开官方桌面应用。重开后查看菜单语言，今后直接从应用程序文件夹打开。更新应用后如果又显示英文，先在「设置 → 通用 → 语言」选择简体中文。仍显示英文时再运行命令。

脚本只写本机语言缓存和桌面语言设置。实际变更配置文件时，在同目录保留 `config.toml.codex-zh.bak.*` 备份。
