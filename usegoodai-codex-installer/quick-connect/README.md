# UseGoodAI中转快速接入助手

编号工具 1，把 Codex 切到 UseGoodAI。两个系统都接收网站「一键导入」生成的同一种 `usegoodai://` 链接：

- **Windows**：单个 `.exe`，双击打开窗口，粘贴 API Key 或点网站的导入链接。源码在本目录根部。
- **Mac**：终端 `.app`，没有窗口。双击时从剪贴板读密钥；点导入链接时把链接里的密钥交给终端里的 `install/codex.sh`。启动器源码在 [macapp/](macapp/)，见下文「Mac 版」。

技术选型：Go 1.25 + Wails v2（WebView2）。不需要管理员权限；系统缺少 WebView2 时弹出中文提示并打开微软下载页。

## 行为

- **导入链接**：每次启动在 `HKCU\Software\Classes\usegoodai` 注册协议，命令为 `"<exe 路径>" "%1"`。单实例：助手已打开时，新链接转给原窗口并置前；未打开时随链接启动并处理。
- **连接流程**（粘贴和链接共用）：去空格、校验格式（`sk-` 开头，只含字母、数字、`-`、`_`）→ `GET https://api.usegoodai.com/v1/usage`（Bearer，10 秒）→ 写入 `%USERPROFILE%\.codex\config.toml` 和 `auth.json` → 关闭当前用户的 codex、chatgpt 进程 → 窗口内提示结果。密钥无效、停用、过期或额度用完，以及检查不了时都不写入。检查不了分三种提示：10 秒内没有回应（含连上后答复卡住）是“网络超时”，解析不了域名、连接被拒或 TLS 失败是“连不上”，其它 HTTP 状态、重定向或返回不是约定的 JSON 是“服务器暂时出错”并带状态码。
- **输入框为空**时点「一键连接 Codex」：提示去网站「API 密钥」页点「一键导入」或复制密钥粘贴，并给出「打开 UseGoodAI 网站」按钮；已连接时提示开头是“当前已连接”。
- **密钥名称**：导入链接带 `name` 时，连接成功后记在 `%APPDATA%\UseGoodAI\QuickConnect\key-names.json`（只存密钥的 SHA-256 和名称，最多 20 条，不存密钥），状态卡在遮挡后的密钥上方显示名称；之后粘贴同一个密钥也显示。`/v1/usage` 不返回密钥名称和分组，手动粘贴的新密钥没有名称；分组要显示时由网站写进 `name`。
- **恢复官方登录**按钮悬停或获得焦点时显示气泡：取消中转站连接，Codex 改回官方账号登录，并关闭正在运行的 Codex。
- **写入内容**与 `install/codex.ps1` 逐字节一致：`.bak.yyyyMMddHHmmss` 备份，UTF-8 无 BOM，先写临时文件再替换，失败时按备份回滚。
- **恢复官方登录**按 `install/codex-restore.ps1` 的规则清理配置并清空 `auth.json`。
- 密钥只在输入框完整显示，其它位置显示前 12 位 + `****` + 后 8 位，不写日志。

## 导入链接格式（与网站约定，不要改）

```text
usegoodai://import?v=1&app=codex&key=<URL 编码>&name=<URL 编码，可选>
```

也接受 `usegoodai://import/?…`。只认 `app=codex`；`v` 大于 1 或其它 `app` 提示下载新版助手。API 地址写死在代码里，链接带地址或其它未知参数一律拒绝；`name` 只用于显示。Windows 和 Mac 共用 `connect/link.go` 的 `ParseImportLink`，规则和提示文字完全一致。以后支持别的工具时，在 `connect/link.go` 放开对应 `app`，再增加该工具的写入函数。

## Mac 版

`.app` 结构：`Contents/MacOS/launcher`（[macapp/](macapp/)，Go + Cocoa）、`Contents/Resources/run.command`（[macapp/run.command](macapp/run.command)）、`Contents/Resources/install.sh`（即 `../install/codex.sh`）。`Info.plist` 用 `CFBundleURLTypes` 登记 `usegoodai` 链接，第一次双击或放进「应用程序」后系统即可把链接交给它。

- **双击**：行为不变，终端运行 `install.sh --from-app`，读剪贴板里的 `sk-` 密钥。
- **导入链接**：启动器用 `ParseImportLink` 检查链接，不合格时弹出与 Windows 相同的提示，不打开终端。合格时在 `~/Library/Caches/com.usegoodai.codex-config/` 下建只有本人可读的命名管道，打开终端运行 `run.command --link <管道路径>`，再把密钥写进管道。`run.command` 读出后以 `USEGOODAI_KEY` 环境变量运行 `install.sh`（不带 `--from-app`，不读剪贴板）。密钥不进命令行参数、终端命令历史和日志，终端只显示 `name` 和遮挡后的密钥。之后的密钥检查、写入配置、关闭 Codex、提示结果都沿用 `codex.sh`。
- **助手已打开 / 未打开**：未打开时系统随链接启动它；还开着时链接直接交给正在运行的启动器。启动器处理完自动退出。
- **只允许一个终端窗口配置**：`run.command` 运行 `install.sh` 期间持有锁 `run.lock`（目录内记录进程号），脚本结束、窗口关闭都会释放，窗口异常消失留下的锁会被下一次自动清理。持锁期间再点导入链接或双击，启动器把终端调到前面并提示「另一个快速接入助手窗口正在配置 Codex……」，不交出新密钥；即使绕过启动器直接运行第二个 `run.command`，它也会拒绝。结束后停在「按回车结束」的窗口不占锁。
- 启动器等终端取密钥最多 5 分钟（含第一次「允许控制终端」的授权），超时删除管道；终端晚开时提示「没有收到网页传来的密钥」。

Mac 启动器用到 Apple 的系统接口，Linux 上编译不了，由仓库根目录的 `.github/workflows/mac-quick-connect.yml` 在 GitHub 的 Apple 芯片 macOS 机器上测试和打包，触发方法见 [../desktop/README.md](../desktop/README.md)。

## 构建

由 `../desktop/build.py` 统一调用，生成编号成品和网站下载文件（Mac 启动器的来源见 [../desktop/README.md](../desktop/README.md)）：

```bash
cd ../desktop && python3 build.py --mac-launcher <Actions 产物里的 Contents/MacOS/launcher>
```

只构建 exe：`python3 build.py [输出路径]`。Go 模块、缓存和临时文件都放在本目录 `.work/`（不进 Git）；`rsrc_windows_amd64.syso`（图标、清单、文件属性）每次构建重新生成。

版本号在 `connect/product.go` 的 `Version`，同时写入 exe 文件属性和窗口底部；`../desktop/build.py` 的 Mac 版本号必须与它一致。Mac 版增加导入链接是同一个软件的更新，不是新软件：版本号沿用 `1.0.0`，Bundle 标识沿用 `com.usegoodai.codex-config`。

## 测试

```bash
W=$PWD/.work
env GOPATH=$W/go-path GOCACHE=$W/go-cache TMPDIR=$W/tmp GOTOOLCHAIN=local GOFLAGS=-modcacherw go test ./...
```

覆盖链接解析、密钥遮挡、`/v1/usage` 各种返回（本地假服务器）、写入结果与 `codex.ps1` 一致、备份命名与回滚、恢复结果与 `codex-restore.ps1` 一致、状态读取、关闭进程的选择、协议注册命令，以及构建后 exe 的架构、大小、图标和文件属性。与 PowerShell 脚本的对照测试需要 `../codex-domestic-models/.dev-tools/pwsh/pwsh`，没有时跳过。

`macapp/` 的测试（Linux 和 Actions 的 Mac 机器都运行，用上面同一条命令）用真实的 `run.command` 和记录参数的假 `install.sh`：逐条读取 `test-link.html` 里的每一种链接（带和不带 `name`），检查合格链接的密钥只以 `USEGOODAI_KEY` 到达 `install.sh`、不出现在终端命令行、进程参数和终端输出里、不读剪贴板，不合格链接给出与 Windows 相同的提示且不开终端；还覆盖双击仍带 `--from-app`、退出码提示、已有窗口在配置时链接和双击都被拒绝、两次快速点击、绕过启动器的第二个窗口、遗留锁的清理、终端没取密钥时的超时和终端打不开的提示。`macapp/smoke_test.sh` 只在 Mac 上运行：确认系统把 `usegoodai://` 交给打出的 `.app`，并实际打开几种链接，检查弹出的提示和启动器自动退出。

`test-link.html` 是本地测试页：填入密钥，生成正常、多斜杠、缺密钥、版本过高、其它工具、带地址参数等链接，在装好助手的 Windows 或 Mac 上点击测试。它不发布到文档站。
