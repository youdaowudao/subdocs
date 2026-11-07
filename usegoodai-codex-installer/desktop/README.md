# 构建双击运行的安装工具

这里维护通用原生启动器，以及 UseGoodAI中转快速接入助手、国产模型导入的本地打包程序。快速接入助手的 Windows 版是 [../quick-connect](../quick-connect/README.md) 的窗口程序；其余成品双击 Windows `.exe` 后自动运行 PowerShell，双击 Apple 芯片 Mac `.app` 后自动打开终端，窗口中继续执行原有脚本，结束后保留结果并等待回车。

## 生成本地成品

快速接入助手的 Mac 启动器（[../quick-connect/macapp](../quick-connect/macapp/)）接收网站的 `usegoodai://` 导入链接，用到 Apple 的系统接口，只能在 Mac 上编译。因此分两步：

1. **在 GitHub Actions 打 Mac 版**（Apple 芯片 macOS 机器，公开仓库免费）。网页：仓库 **Actions** → **Mac 快速接入助手打包** → **Run workflow**，分支选 `main`。或用命令：

   ```bash
   gh workflow run mac-quick-connect.yml --ref main
   gh run watch "$(gh run list --workflow mac-quick-connect.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
   gh run download <运行编号> --name usegoodai-quick-connect-mac-arm64 --dir <下载目录>
   ```

   工作流先跑链接解析和 `USEGOODAI_KEY` 传入的测试，再执行 `python3 build.py --mac-only`、检查成品，并在那台 Mac 上实际打开几种导入链接（`../quick-connect/macapp/smoke_test.sh`）。产物 `usegoodai-quick-connect-mac-arm64.zip` 就是网站下载文件：压缩包内是不带编号的 `UseGoodAI中转快速接入助手.app`，保留可执行权限，保留 30 天。工作流不使用任何密钥或 Secrets，测试只用临时生成的假密钥，日志里不打印。

2. **在本目录生成全部成品**，Mac 启动器取自上一步的产物：

   ```bash
   unzip -q <下载目录>/usegoodai-quick-connect-mac-arm64.zip -d <解压目录>
   python3 build.py --mac-launcher "<解压目录>/UseGoodAI中转快速接入助手.app/Contents/MacOS/launcher"
   ```

   不带 `--mac-launcher` 时在 Mac 上就地编译，在 Linux 上提示先触发 Actions。

成品写入 `../dist/desktop/Windows-x64/` 和 `../dist/desktop/Mac-Apple芯片/`。两项工具分别生成 `1.UseGoodAI中转快速接入助手` 和 `3.Codex国产模型导入` 的 `.exe`、`.app`；编号 2 留给生图子项目生成的 `2.UseGoodAI生图工具`。构建前清空 `../dist/desktop/`，被替换的旧成品不会残留。终端类成品在 Windows 使用系统 PowerShell 5.1；当前 Go 1.25 构建面向 Windows 10/11 x64 和 macOS 12 及以上的 Apple Silicon。

快速接入助手的 Mac `.app` 在 `Info.plist` 用 `CFBundleURLTypes` 登记 `usegoodai` 链接，`Contents/Resources/run.command` 取自 `../quick-connect/macapp/run.command`：双击时运行 `../install/codex.sh --from-app` 读剪贴板里的 `sk-` 密钥；点网站「一键导入」时密钥经 `USEGOODAI_KEY` 传入，不读剪贴板。同一时间只允许一个终端窗口配置 Codex。细节见 [../quick-connect/README.md](../quick-connect/README.md)。沿用旧版 `com.usegoodai.codex-config` 标识，已授予的终端权限继续有效。同时生成网站下载文件 `../dist/desktop/download/usegoodai-quick-connect-windows-x64.exe` 和 `usegoodai-quick-connect-mac-arm64.zip`；本地生成的 Mac 压缩包与 Actions 产物内容相同。

Windows 启动器内附原始 PowerShell 脚本，运行时在当前用户临时目录展开并启动，结束后清理临时文件。中文脚本带 UTF-8 BOM，支持 Windows PowerShell 5.1。Mac `.app` 内附原始 Shell 脚本，使用系统终端运行；整个 `.app` 目录是一个应用，移动或压缩时保留完整目录和可执行权限。

原脚本仍只在 `../install/` 维护。打包不修改配置行为、模型数据、备份和关闭客户端逻辑，也不下载依赖。接入配置和模型导入按需分别运行；两项都运行时，先接入配置，再导入模型。

## 验证启动器和成品

```bash
go test ./... -v
python3 -m unittest test_packaging.py -v
```

测试覆盖自解压成品读取、非法文件拒绝、临时文件清理、输入与输出转发、失败退出码、中文及带引号路径、终端交互、只有快速接入助手读剪贴板、下载压缩包权限、PE/Mach-O 架构与原始脚本一致性，以及快速接入助手 `.app` 的链接登记、专用启动器和 `run.command`。Actions 的 Mac 机器设置 `USEGOODAI_MAC_ONLY=1`，只跑 Mac 成品相关的几项，并额外用 `plutil`、`codesign --verify` 检查。打包程序和 Python 包装测试的缓存、临时目录保存在本目录 `.work/`。

本地和 Actions 构建都不包含发布者代码签名或 Apple 公证（Mac 启动器只有编译器自动加的临时签名）。Windows 和 Mac 的真实桌面双击验证需分别在目标系统完成；Linux 自动化验证不能代替实机验收。

2026-10-24 在 Linux 完成启动器 2 项 Go 测试和 3 项 Python 包装测试，全部通过；六份成品的 Windows x64、Mac arm64 架构及内置脚本/程序均已核对。

2026-11-01 在 Linux 完成启动器 Go 测试和 6 项 Python 包装测试，全部通过；快速接入助手 exe（x64 窗口程序）、两份 Mac `.app` 与网站下载文件均已核对。

## 供生图工具复用启动器

`../../usegoodai-imagines-tool/release/build_desktop.py` 只读取这里的通用启动器和打包函数，把已核对的 V0.9.1 原生程序装入独立成品。生图源码、版本和打包入口继续在生图子项目维护；其缓存及成品留在生图子项目 `dist/`，不改动线上安装脚本或父仓库发布目录。Windows 合并版由 `quick-connect/build.py` 内附同版程序、Skill 和规则，支持 GPT Image 2.6 与 GIF 参数，并写入放行生图工具全部子命令的 Codex 规则。

## 网页交付

从 2026-11-05 起，最终合集发布到父仓库 `docs/public/download/usegoodai-tools.zip`，下载地址固定为 `https://docs.usegoodai.com/download/usegoodai-tools.zip`。`docs/public/_headers` 设置中文附件名 `中转站快速导入工具_年月日-时分.zip`，每次发布同步改时间；成品不再复制到项目外的“传资料”目录。

交付 ZIP 中 Windows 只有 `1.UseGoodAI中转快速接入助手.exe`，生图和国产模型导入使用同一窗口；Mac 保留 1、2、3 三个 `.app`。根目录只放 `使用说明.txt`，内部校验记录不放进 ZIP。发布前运行父仓库 `tests/quick-connect-download.test.mjs`，验证单一 Windows EXE、内嵌生图版本、Mac 三工具及下载文件名。
