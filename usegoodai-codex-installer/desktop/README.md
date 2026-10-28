# 构建双击运行的安装工具

这里维护通用原生启动器，以及 Codex 接入配置、国产模型导入的本地打包程序。用户双击 Windows `.exe` 后自动运行 PowerShell；双击 Apple 芯片 Mac `.app` 后自动打开终端。窗口中继续执行原有脚本，结束后保留结果并等待回车。

## 生成本地成品

在本目录执行：

```bash
python3 build.py
```

成品写入 `../dist/desktop/Windows-x64/` 和 `../dist/desktop/Mac-Apple芯片/`。两项工具分别生成 `1.Codex接入配置` 和 `3.Codex国产模型导入` 的 `.exe`、`.app`，不创建压缩包；编号 2 留给生图子项目生成的 `2.UseGoodAI生图工具`。Windows 使用系统 PowerShell 5.1；当前 Go 1.25 构建面向 Windows 10/11 x64 和 macOS 12 及以上的 Apple Silicon。

Windows 启动器内附原始 PowerShell 脚本，运行时在当前用户临时目录展开并启动，结束后清理临时文件。中文脚本带 UTF-8 BOM，支持 Windows PowerShell 5.1。Mac `.app` 内附原始 Shell 脚本，使用系统终端运行；整个 `.app` 目录是一个应用，移动或压缩时保留完整目录和可执行权限。

原脚本仍只在 `../install/` 维护。打包不修改配置行为、模型数据、备份和关闭客户端逻辑，也不下载依赖。接入配置和模型导入按需分别运行；两项都运行时，先接入配置，再导入模型。

## 验证启动器和成品

```bash
go test ./... -v
python3 -m unittest test_packaging.py -v
```

测试覆盖自解压成品读取、非法文件拒绝、临时文件清理、输入与输出转发、失败退出码、中文及带引号路径、终端交互、PE/Mach-O 架构与原始脚本一致性。打包程序和 Python 包装测试的缓存、临时目录保存在本目录 `.work/`。

本地构建不包含发布者代码签名或 Apple 公证。Windows 和 Mac 的真实桌面双击验证需分别在目标系统完成；Linux 自动化验证不能代替实机验收。

2026-10-24 在 Linux 完成启动器 2 项 Go 测试和 3 项 Python 包装测试，全部通过；六份成品的 Windows x64、Mac arm64 架构及内置脚本/程序均已核对。

## 供生图工具复用启动器

`../../usegoodai-imagines-tool/release/build_desktop.py` 只读取这里的通用启动器和打包函数，把已核对的 V0.8.2 原生程序装入独立成品。生图源码、版本和打包入口继续在生图子项目维护；其缓存及成品留在生图子项目 `dist/`，不改动线上安装脚本或父仓库发布目录。
