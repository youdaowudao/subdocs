# UseGoodAI中转快速接入助手

编号工具 1，把 Codex 切到 UseGoodAI；Windows 版还能把 Claude 桌面版（Claude App）切到 UseGoodAI。两个系统都接收网站「一键导入」生成的同一种 `usegoodai://` 链接：

- **Windows**：单个 `.exe`，双击打开窗口，粘贴 API Key 或点网站的导入链接。源码在本目录根部。
- **Mac**：终端 `.app`，没有窗口。双击时从剪贴板读密钥；点导入链接时把链接里的密钥交给终端里的 `install/codex.sh`。启动器源码在 [macapp/](macapp/)，见下文「Mac 版」。

技术选型：Go 1.25 + Wails v2（WebView2）。不需要管理员权限；系统缺少 WebView2 时弹出中文提示并打开微软下载页。

## 1.1.12（2026-11-11）

- Mac 版改为在 Apple 芯片 Mac 上整体临时签名，修复经浏览器下载后双击提示“已损坏，无法打开”；内置生图工具 0.9.5（同样签名）。Windows 版只更新版本号与内置生图 0.9.5，行为不变。
- 测试记录见 [Mac 工具提示已损坏的复现与修复](../test-records/20261111-mac-damaged.md)。

## 1.1.11（2026-11-11）

- 内置生图工具 0.9.4：联网跟随 VPN 的系统代理（Windows 读取当前用户 Internet Settings），开着 VPN「系统代理」、网络只能经 VPN 到达时不再超时；连不上网时按 VPN 没运行、VPN 连不上、PAC 模式、没有系统代理给出指导，不再误报放行规则没有生效。
- 助手自身行为不变。1.1.8～1.1.10 已用于未合并的 Windows 启动排查候选（PR #4），为避免同号不同内容，本次正式版直接使用 1.1.11。
- 测试记录见 [生图 0.9.4 VPN 系统代理发布测试](../test-records/20261111-image-vpn-proxy.md)。

## 1.1.7（2026-11-10）

- 内置生图工具 0.9.3。旧版本和目标版本同时显示；缺少 Key 的旧安装同样显示升级按钮。
- 升级已有安装调用 `install --keep-key`，不要求新 Key、不做余额/密钥/模型网络检查，保留 Key 原样；没有 Key 也可先升级再补。
- 已有生图安装不自动读取剪贴板，防止升级时误导入编程密钥；主动粘贴或网站导入仍走新密钥检查。
- 测试记录见 [生图工具升级测试](../test-records/20261110-image-upgrade.md)，未执行的桌面和真实接口项目明确列出。

## 行为

- **导入链接**：每次启动在 `HKCU\Software\Classes\usegoodai` 注册协议，命令为 `"<exe 路径>" "%1"`。单实例：助手已打开时，新链接转给原窗口并置前；未打开时随链接启动并处理。
- **连接流程**（粘贴和链接共用）：去空格、校验格式（`sk-` 开头，只含字母、数字、`-`、`_`）→ `GET https://api.usegoodai.com/v1/usage`（Bearer，10 秒）→ 写入 `%USERPROFILE%\.codex\config.toml` 和 `auth.json` → 关闭当前用户的 codex、chatgpt 进程 → 窗口内提示结果。密钥无效、停用、过期或额度用完，以及检查不了时都不写入。检查不了分三种提示：10 秒内没有回应（含连上后答复卡住）是“网络超时”，解析不了域名、连接被拒或 TLS 失败是“连不上”，其它 HTTP 状态、重定向或返回不是约定的 JSON 是“服务器暂时出错”并带状态码。
- **输入框为空**时点「一键连接 Codex」：提示去网站「API 密钥」页点「一键导入」或复制密钥粘贴，并给出「打开 UseGoodAI 网站」按钮；已连接时提示开头是“当前已连接”。
- **密钥名称**：导入链接带 `name` 时，连接成功后记在 `%APPDATA%\UseGoodAI\QuickConnect\key-names.json`（只存密钥的 SHA-256 和名称，最多 20 条，不存密钥），状态卡在遮挡后的密钥上方显示名称；之后粘贴同一个密钥也显示。`/v1/usage` 不返回密钥名称和分组，手动粘贴的新密钥没有名称；分组要显示时由网站写进 `name`。
- **恢复官方登录**按钮悬停或获得焦点时显示气泡：取消中转站连接，Codex 改回官方账号登录，并关闭正在运行的 Codex。
- **写入内容**与 `install/codex.ps1` 逐字节一致：`.bak.yyyyMMddHHmmss` 备份，UTF-8 无 BOM，先写临时文件再替换，失败时按备份回滚。
- **恢复官方登录**按 `install/codex-restore.ps1` 的规则清理配置并清空 `auth.json`。
- 密钥只在输入框完整显示，其它位置显示前 12 位 + `****` + 后 8 位，不写日志。

## Claude 桌面版（Windows）

品牌行右侧的「Codex / Claude」两个标签切换主入口，Claude 页用陶土橙主题，复用同一张状态卡、输入框和主按钮。只支持官网下载的新版（Microsoft Store 包 `Claude_pzs8sxrjxfjjc`），旧的 `%LOCALAPPDATA%\AnthropicClaude` 安装不处理。

- **检测**：`%LOCALAPPDATA%\Packages\Claude_*` 存在算已安装。没装时状态卡显示「没检测到 Claude 桌面版」和「官网下载 / 群文件下载」两个按钮，不写任何文件。
- **连接流程**：`/v1/usage` 检查密钥（同 Codex）→ `GET /v1/models` → 只留官方格式的 Fable、Opus、Sonnet、Haiku 模型（`^claude-(fable|opus|sonnet|haiku)-主版本(-次版本)?(-8位日期)?$`，同一版本有不带日期的就去掉带日期的；`claude-opus-5.5`、大小写不对、`[1m]`、`-thinking`、带前缀的一律丢弃，不改写），顺序 Fable、Opus、Sonnet、Haiku，同系列新版本在前，第一条是 Claude 的默认模型。一个都没有就提示换分组，不写入。
- **写入**（全部成功或全部不改，配置文件和 `_meta.json` 先做 `.bak.时间` 备份，其它字段和顺序保留）：
  - `deploymentMode: "3p"` 写进三份 `claude_desktop_config.json`：`%LOCALAPPDATA%\Claude-3p\`、`%LOCALAPPDATA%\Claude\`、`Packages\Claude_*\LocalCache\Roaming\Claude\`。
  - `%LOCALAPPDATA%\Claude-3p\configLibrary\00000000-0000-4000-8000-00000000600d.json`：网关地址、Bearer、密钥、`modelDiscoveryEnabled: false`、`inferenceModels`。
  - `_meta.json`：登记 `UseGoodAI` 条目，`appliedId` 指向它；CC Switch 等其它条目保留不动。
- **关闭 Claude**：只结束从 `WindowsApps\Claude_*` 运行的 `claude.exe`，Claude Code CLI（同名 `claude.exe`）不受影响。
- **Claude Code CLI**：只查 `%USERPROFILE%\.local\bin\claude.exe` 和 `%APPDATA%\npm\claude.cmd`。找到且还没用这个密钥时，连接成功后弹窗「检测到 Claude Code CLI，是否同时接入？」，点「是」写 `~/.claude/settings.json` 的 `env`（`ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`，并去掉 `ANTHROPIC_API_KEY` 和模型覆盖变量），其它设置保留；没找到不提示。
- **恢复官方登录**：UseGoodAI 是当前生效的配置时，三份配置改回 `1p`；生效的是别家（如 CC Switch）时不动模式。然后从 `_meta.json` 去掉 UseGoodAI 条目（`appliedId` 交给下一条，没有就删除），删除含密钥的 UseGoodAI 配置文件，关闭 Claude。Claude Code CLI 指向 UseGoodAI 时，同时去掉 `env` 里的 `ANTHROPIC_BASE_URL` 和 `ANTHROPIC_AUTH_TOKEN`（先备份），指向别家的不动。

Codex 页没检测到 ChatGPT/Codex（没有 `Packages\OpenAI.*`，也没有 `.codex` 文件夹）时，同样显示下载按钮，官网下载打开 `https://chatgpt.com/download/`。QQ 卡片写明群文件有两个软件的安装包，点「群文件下载」会高亮 QQ 卡片并提示进群下载。

## 三个工具共用一个面板（Windows）

窗口默认是 Codex 接入。生图工具和国产模型导入不单独做页签：面板上方的状态卡、输入框和主按钮位置不变，只换内容和主题色（Codex 青蓝、生图紫、国产模型琥珀），切换时一道光扫过。两个工具的入口是中下部、QQ 卡片上方的两颗浅色小按钮，按钮上直接写状态（「生图工具（已安装）」「国产模型（已导入）」「国产模型（需重新导入）」），避免重复安装；进入其中一个工具后，对应入口换成「返回 Codex 接入」。安装或导入成功后自动回到 Codex，结果留在提示条。

网站导入链接：停在生图工具时交给生图工具，其余情况切回 Codex 照常接入。生图状态只在窗口里，窗口关掉后再点链接仍按 Codex 处理，所以提示条要求导入完成前不关窗口。

### 生图工具

- **检测**：先用 `/v1/usage` 确认密钥可用，再查 `GET /v1/models`。列表里没有任何 `gpt-image` 开头的模型，判定为选错分组、不安装；有就安装。编程分组也带画图模型、画图分组也有其他画图模型，所以不按分组区分，能画就算对；接入 Codex 也不按模型拦截。
- **安装**：助手内附生图工具已发布的程序（见 [imagetool/README.md](imagetool/README.md)），运行前核对 SHA-256，解到 `%LOCALAPPDATA%\UseGoodAI\QuickConnect\image-tool\`，以 `CODEX_HOME=<目录> install` 运行、密钥从标准输入传入，与客户在终端里输入完全相同；不弹控制台窗口，不碰 Codex 配置、不关闭 Codex。失败时显示生图程序的「安装失败：」原因（密钥会被遮挡）。
- **状态**：读 `<CODEX_HOME 或 ~/.codex>\tools\usegoodai-imagines-tool\` 的 `install-manifest.json`、`api-key`、`key-source`。
- **升级**：状态按已安装版本与内置版本比较，缺 Key 时也显示旧版本和升级按钮。输入框留空直接升级程序，保留原 Key，不联网检查凭据；粘贴新 Key 才验证并替换。较新的安装保留、不降级。维护时改 `build.py` 的 `IMAGE_TOOL_RELEASE` 再打包。

### 国产模型导入

- **运行**：助手内附 `../install/codex-models.ps1`（见 [modelstool/README.md](modelstool/README.md)），在后台用 Windows PowerShell 以 `-NoProfile -NonInteractive -ExecutionPolicy Bypass` 运行，不弹控制台窗口；脚本路径和 `CODEX_HOME` 经环境变量传入，中文用户名和带引号的路径不用转义。输出要求 UTF-8，控制台不肯切换时按 GB18030 解码。脚本原样负责导入、移除和关闭 ChatGPT/Codex。
- **确认**：主按钮第一次点击变成「确认导入（会关闭 Codex）」，6 秒内再点才开始；「移除国产模型」同样两次确认。不需要密钥，所以这一页没有输入框。
- **状态**：数 `usegoodai-models.managed.json` 里非 `gpt-` 的条目，再看 `config.toml` 的 `model_catalog_json` 是否指向 `usegoodai-models.json`。重新连接 Codex 会重写 `config.toml`（只保留 `[windows]` 沙箱设置），导入的模型随之失效，状态显示「需重新导入」。
- **升级**：国产模型脚本只在 `codex-domestic-models/` 维护，按那边流程同步到 `install/` 和发布目录后重新运行 `build.py`；打包时核对内附脚本与发布副本除 BOM 外逐字节一致。

Mac 版仍是终端 `.app`、没有窗口（不做 Apple 签名，未签名的窗口版首次打开同样要去系统设置放行），生图和国产模型仍用各自的 `.app`。

## 导入链接格式（与网站约定，不要改）

```text
usegoodai://import?v=1&app=codex&key=<URL 编码>&name=<URL 编码，可选>
usegoodai://import?v=1&app=claude&key=<URL 编码>&name=<URL 编码，可选>
```

也接受 `usegoodai://import/?…`。认 `app=codex` 和 `app=claude`（Windows 版切到 Claude 页连接 Claude 桌面版；Mac 版提示一键导入 Claude 只有 Windows 版支持）；`v` 大于 1 或其它 `app` 提示下载新版助手。API 地址写死在代码里，链接带地址或其它未知参数一律拒绝；`name` 只用于显示。Windows 和 Mac 共用 `connect/link.go` 的 `ParseImportLink`，规则和提示文字完全一致。以后支持别的工具时，在 `connect/link.go` 放开对应 `app`，再增加该工具的写入函数。

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

版本号在 `connect/product.go` 的 `Version`，同时写入 exe 文件属性和窗口底部；`../desktop/build.py` 的 Mac 版本号必须与它一致。每次给用户的新版本都要加版本号（1.0.0 首发；1.1.0 加入 Codex 完全访问和 Claude 桌面版接入；之后每个测试版只加最后一位：1.1.1、1.1.2……），Bundle 标识沿用 `com.usegoodai.codex-config`，让 Mac 的终端控制权限延续。

## 测试

```bash
W=$PWD/.work
env GOPATH=$W/go-path GOCACHE=$W/go-cache TMPDIR=$W/tmp GOTOOLCHAIN=local GOFLAGS=-modcacherw go test ./...
```

覆盖链接解析、密钥遮挡、`/v1/usage` 各种返回（本地假服务器）、写入结果与 `codex.ps1` 一致、备份命名与回滚、恢复结果与 `codex-restore.ps1` 一致、状态读取、关闭进程的选择、协议注册命令，以及构建后 exe 的架构、大小、图标和文件属性。与 PowerShell 脚本的对照测试需要 `../codex-domestic-models/.dev-tools/pwsh/pwsh`，没有时跳过。

`macapp/` 的测试（Linux 和 Actions 的 Mac 机器都运行，用上面同一条命令）用真实的 `run.command` 和记录参数的假 `install.sh`：逐条读取 `test-link.html` 里的每一种链接（带和不带 `name`），检查合格链接的密钥只以 `USEGOODAI_KEY` 到达 `install.sh`、不出现在终端命令行、进程参数和终端输出里、不读剪贴板，不合格链接给出与 Windows 相同的提示且不开终端；还覆盖双击仍带 `--from-app`、退出码提示、已有窗口在配置时链接和双击都被拒绝、两次快速点击、绕过启动器的第二个窗口、遗留锁的清理、终端没取密钥时的超时和终端打不开的提示。`macapp/smoke_test.sh` 只在 Mac 上运行：确认系统把 `usegoodai://` 交给打出的 `.app`，并实际打开几种链接，检查弹出的提示和启动器自动退出。

`test-link.html` 是本地测试页：填入密钥，生成正常、多斜杠、缺密钥、版本过高、其它工具、带地址参数等链接，在装好助手的 Windows 或 Mac 上点击测试。它不发布到文档站。
