# UseGoodAI中转快速接入助手（Windows 窗口版）

编号工具 1 的 Windows 版本：单个 `.exe`，双击打开窗口，粘贴 API Key 或点网站的导入链接，把 Codex 切到 UseGoodAI。Mac 版仍是 [../desktop](../desktop/README.md) 打出的终端 `.app`，从剪贴板读取密钥后运行 `install/codex.sh`。

技术选型：Go 1.25 + Wails v2（WebView2）。不需要管理员权限；系统缺少 WebView2 时弹出中文提示并打开微软下载页。

## 行为

- **导入链接**：每次启动在 `HKCU\Software\Classes\usegoodai` 注册协议，命令为 `"<exe 路径>" "%1"`。单实例：助手已打开时，新链接转给原窗口并置前；未打开时随链接启动并处理。
- **连接流程**（粘贴和链接共用）：去空格、校验 `sk-` → `GET https://api.usegoodai.com/v1/usage`（Bearer，10 秒）→ 写入 `%USERPROFILE%\.codex\config.toml` 和 `auth.json` → 关闭当前用户的 codex、chatgpt 进程 → 窗口内提示结果。密钥无效、停用、过期或额度用完、连不上服务器时不写入。
- **写入内容**与 `install/codex.ps1` 逐字节一致：`.bak.yyyyMMddHHmmss` 备份，UTF-8 无 BOM，先写临时文件再替换，失败时按备份回滚。
- **恢复官方登录**按 `install/codex-restore.ps1` 的规则清理配置并清空 `auth.json`。
- 密钥只在输入框完整显示，其它位置显示前 12 位 + `****` + 后 8 位，不写日志。

## 导入链接格式（与网站约定，不要改）

```text
usegoodai://import?v=1&app=codex&key=<URL 编码>&name=<URL 编码，可选>
```

也接受 `usegoodai://import/?…`。只认 `app=codex`；`v` 大于 1 或其它 `app` 提示下载新版助手。API 地址写死在代码里，链接带地址或其它未知参数一律拒绝；`name` 只用于显示。以后支持别的工具时，在 `connect/link.go` 放开对应 `app`，再增加该工具的写入函数。

## 构建

由 `../desktop/build.py` 统一调用，生成编号成品和网站下载文件：

```bash
cd ../desktop && python3 build.py
```

只构建 exe：`python3 build.py [输出路径]`。Go 模块、缓存和临时文件都放在本目录 `.work/`（不进 Git）；`rsrc_windows_amd64.syso`（图标、清单、文件属性）每次构建重新生成。

版本号在 `connect/product.go` 的 `Version`，同时写入 exe 文件属性和窗口底部；`../desktop/build.py` 的 Mac 版本号必须与它一致。

## 测试

```bash
W=$PWD/.work
env GOPATH=$W/go-path GOCACHE=$W/go-cache TMPDIR=$W/tmp GOTOOLCHAIN=local GOFLAGS=-modcacherw go test ./...
```

覆盖链接解析、密钥遮挡、`/v1/usage` 各种返回（本地假服务器）、写入结果与 `codex.ps1` 一致、备份命名与回滚、恢复结果与 `codex-restore.ps1` 一致、状态读取、关闭进程的选择、协议注册命令，以及构建后 exe 的架构、大小、图标和文件属性。与 PowerShell 脚本的对照测试需要 `../codex-domestic-models/.dev-tools/pwsh/pwsh`，没有时跳过。

`test-link.html` 是本地测试页：填入密钥，生成正常、多斜杠、缺密钥、版本过高、其它工具、带地址参数等链接，在装好助手的 Windows 上点击测试。它不发布到文档站。
