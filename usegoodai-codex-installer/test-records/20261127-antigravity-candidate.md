# Antigravity App 原生接入测试候选（2026-11-27 JST，未正式发布）

## 范围与版本

- Windows 快速接入助手 1.2.4（基线 1.2.3）：新增 Antigravity 接入卡、v2 网页导入、当前用户 AGY 网关环境变量及恢复。无需管理员权限、不修改官方 App。旧 Codex、Claude、生图和国产模型业务保留。
- Mac 快速接入助手 1.1.16（基线 1.1.15）：网页链接直达；双击时选择软件，Antigravity 连接、打开、恢复通过终端菜单；仅将环境变量传入官方 App 进程。原 Codex 脚本保持。
- 修正：Linux 与 Mac 直接使用 Shell 接入命令 1.0.1（connect/open/restore/status/version），不交付独立 Linux 可执行程序。与 Mac 助手共用用户配置，启动官方 App 时传入环境变量。
- 只读取现有 `/v1beta/models`，Bearer Key 鉴权；保留实际 Gemini 模型 ID，过滤非编程模型。不改主站后端、分组、计费、数据库。每次显式接入新增一次既有原生模型列表查询；普通推理请求零额外读写。主站由独立会话实施，契约 `usegoodai://import?v=2&app=antigravity&key=...&name=...`。
- 冻结程序及构建代号：`84f44728a8b8bb61737bf897e1f3706917b74bc4`；后续测试工作流不改程序代码或候选成品。候选来源 [三平台构建及实测 45849186242](https://github.com/youdaowudao/subdocs/actions/runs/45849186242)。

## 验收结果

| 系统 | 官方 App 2.35.2 配置、流式对话（模拟服务） | 成品入口 |
| --- | --- | --- |
| Windows 11 Enterprise 10.0.26200、ARM64 运行 x64 助手及官方 x64 App | 通过：当前用户注册表写入/恢复、实际官方 App 启动、原生 GET 模型列表及 POST SSE、实际 Electron 渲染界面回复。系统初始化隐私向导挡住前台，采用只在测试运行器上启用的本地 CDP 操作真正渲染的 App；未视为屏幕前台通过。 | 同一 EXE 成功建窗、注册 usegoodai://、把后续链接交给已开窗口（启动日志）；WebView2 调试端口不可用，新标签页可见反馈未核实。相同 EXE 的 --antigravity connect 经正式站假 Key 返回 401，无配置写入：[命令复核](https://github.com/youdaowudao/subdocs/actions/runs/45854159459)。未用 Windows Server；原生 x64 硬件和开始菜单重开后的环境继承待用户实际复核。 |
| macOS 15.8.2、arm64 | 通过：真实 App 窗口，系统 UI 操作发送 test 后显示模拟回复，原生模型路径及 Bearer 已核对。 | 整体签名和严格 codesign 验证通过；解压签名候选后系统链接直接进入 Antigravity 并拒绝假 Key。浏览器隔离标记打开显示 Apple 无法验证开发者的标准拦截（非“已损坏”）；运行器未完成系统“仍要打开”的人工批准，不能算批准后打开通过。 |
| Ubuntu 24.04 x64 | 通过：真实 App 窗口、实际点击发送 test、原生 SSE 和模拟回复。运行器需为官方 App 配好 Chromium sandbox 文件的权限，未使用 --no-sandbox；这不属于接入命令的权限要求。 | 修正后的 1.0.1 Shell 命令直接运行：真实 App 经模拟服务回复通过；通过 GitHub 原始脚本地址执行假 Key，正式站返回 401、退出 1、未写配置。 |

- 证据 [三平台 App 原生验收](https://github.com/youdaowudao/subdocs/actions/runs/45849186242) 全部成功，含截图、请求日志：Windows [15134245633](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15134245633)，Mac [15133510606](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15133510606)，Linux [15132487050](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15132487050)。
- 精确成品入口 [45852416407](https://github.com/youdaowudao/subdocs/actions/runs/45852416407)：Mac 成功；Linux 原测试入口已由直接 Shell 脚本替代；Windows 前台及 WebView2 自动化未完成，已保存实际启动记录，另以精确 EXE 命令补测通过，不隐瞒限制。
- Mac 签名隔离标记记录 [15133106713](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15133106713)。原 Mac 快速接入助手打包/旧链接回归 [45849186146](https://github.com/youdaowudao/subdocs/actions/runs/45849186146) 成功。
- 本地 Linux 全 Go 回归（包含 Windows 新候选 PE 资源检查）和 Windows x64 交叉构建通过；前端 JavaScript 语法通过。
- 首轮问题：Windows 构建日志中文 stdout、Mac 首次加载时间、Ubuntu 官方 App sandbox 权限；后续 Windows 回归引用查询超时与前台隐私向导受阻。已修复测试流程；未改变正式门禁。
- 尚未验证：真实用户 Key 的成功推理、上游稳定性、真实计费、完整多轮文件操作；用户将在 Windows 和 Linux 自行实测。未索取真实 Key。
- 主站独立会话回复：v0.2.25-3，PR #31 已合并，代码未部署生产；契约一致。工具不依赖主站新增后端。

## 成品与哈希

冻结构建产物（Actions 保留 30 天）：

| 产物 | SHA-256 |
| --- | --- |
| [Windows 1.2.4](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15133975444) | `4b484bde826097d591e775cee190be946e624b0a7991447abdda1269b1816786` |
| [Mac 1.1.16 已签名 ZIP](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15132871449) | `a428d9422d4d79fd93fe6d90fa6826bd95cf397d0603194f69050c65a17119e2` |

组合本地候选 `下载成品/中转站快速导入工具_20261127-1241_Antigravity测试候选.zip`，10,584,740 字节，SHA-256 `a92767636e954713e75f4d9698c3f9f0707af85a87128ece3d2880479ba6575c`。只有 Windows 和 Mac 成品，保留已验证的原候选字节，核对 Mac 签名件、Windows EXE 哈希和归档 CRC。

## 发布边界

仅提交、推送固定 `actions-test`。正式站 `main/origin/main` 保持 `bff057b5159d7d82b7b43059afd42d06fc1d449f`；仅在 actions-test 同步新的 Antigravity Shell 脚本，正式站发布目录未替换。正式下载文件仍是旧版本，正式门禁的发布文件检查必然因候选版本与未替换的成品不符而失败（[45849186293](https://github.com/youdaowudao/subdocs/actions/runs/45849186293)，另两项既有门禁通过），未移除、跳过或放宽门禁。用户验收后才另行同步成品、执行正式发布门禁及上线，不将本次候选认作已发布。


## 交付形式纠正（2026-11-27 12:42 JST）

用户明确 Linux 只用命令执行、不得交付独立可执行包。已删除错误的含 Linux 程序的本地合集和四个 GitHub Linux 二进制产物；当前源码不再构建或上传 Linux 可执行包。Windows 1.2.4 与 Mac 1.1.16 已测试的成品不重做，重新组合为仅 Windows 与 Mac 的 ZIP。

直接终端命令（Mac / Linux 共用；使用文档站 Actions 测试分支预览地址，不使用 GitHub 原始文件域名）：

```bash
curl -fsSL https://actions-test.subdocs.pages.dev/install/antigravity.sh | bash
```

用户报告原 GitHub raw 地址下载时连接重置，改为上述既有 Cloudflare Pages 预览地址。2026-11-27 实际 HTTP 下载成功，脚本 SHA-256 `873175f9b13e52ca3daf0ab5d4582cba54245861544bd20d989a728d0ca7176c` 与测试分支逐字节一致，管道运行 `version` 返回 1.0.1。正式发布后使用 `https://docs.usegoodai.com/install/antigravity.sh`，本次未发布主线；用户侧预览域名的连通性仍待确认。

重新打开时在 bash 后加 `-s -- open`，恢复官方登录加 `-s -- restore`。Linux 依赖本机已有 Python 3 读取 Gemini JSON；Mac 用系统 JXA，无需安装其他依赖。仅写当前用户配置，不修改 App 本体、不使用 sudo。

- 源码与测试分支将来发布副本逐字节一致：`usegoodai-codex-installer/install/antigravity.sh` 与 `docs/public/install/antigravity.sh`。
- [Shell 实际 App 验收 45935555597](https://github.com/youdaowudao/subdocs/actions/runs/45935555597)：Linux [15170289497](https://github.com/youdaowudao/subdocs/actions/runs/45935555597/artifacts/15170289497)、Mac [15170421887](https://github.com/youdaowudao/subdocs/actions/runs/45935555597/artifacts/15170421887)。两者均经实际 Shell 命令查询原生模型，打开官方 App，发送 test 并显示本地模拟回复，恢复测试通过。正式 URL 假 Key 返回 401，无写入。
- Windows 原候选保持不变。没有正式发布，实际真实 Key 和计费仍待用户验收。

## Shell 1.0.2 用户验收修正（2026-11-27，未发布）

- Google 官方 Linux App 是 tar.gz 解压版，无强制固定安装目录；官方 2.35.2 x64 包已核对 `Antigravity-x64/antigravity`、`resources/app.asar`、`resources/bin/language_server`。仅检查常用固定目录及系统下载目录，不作全盘或递归搜索。其他解压位置由用户填目录或程序完整路径，支持 `~`、中文和空格；保存后复用。Windows 和 Mac 已冻结成品未变。
- 终端输入 API Key 明文显示，便于新手检查；仍不把 Key 作为 API 请求命令行参数、不输出额外日志。
- 本地四项伪终端交互测试通过：标准下载目录、中文自定义下载目录 ARM64 布局、自定义文件夹含空格和 `~`、显式程序路径与同名非 App；每项均验证假 Key 可见、401 不写配置。官方真实 App 测试改为默认命令，不再通过 `--app` 绕过定位。[45936946147](https://github.com/youdaowudao/subdocs/actions/runs/45936946147) 的 Windows、Mac、Linux 三项全部成功，包括 Linux/Mac 默认目录识别、真实 App 调用模拟 Gemini 原生接口并收到回复。Windows 成品代码未改变。Linux [15170922929](https://github.com/youdaowudao/subdocs/actions/runs/45936946147/artifacts/15170922929)，Mac [15170549194](https://github.com/youdaowudao/subdocs/actions/runs/45936946147/artifacts/15170549194)。
- 测试预览命令保持不变，正式主线未发布。
- 测试站实际返回 1.0.2，在线文件 SHA-256 `b30b85fe52d98f2d70512ed89799cf320fa5012e9e17604c3f5353d17b09fa21` 与源码及发布副本一致；本地 Go connect/macapp 回归通过。用户在 Linux 实际输入真实密钥并确认能够使用 App；未独立核实真实计费。
- 用户确认仅做独立官方 Antigravity App，不开发 IDE、CLI 或编辑器扩展。Google 在 [2026-05-19 产品发布](https://antigravity.google/blog/introducing-google-antigravity-2-0) 和 [2026-08-20 IDE 扩展说明](https://antigravity.google/blog/antigravity-ide-extensions) 中明确独立 App 是产品发展重点，IDE 用于编辑、调试等专业场景。

## 用户 Windows 实测后修正（未发布）

- 用户确认原 Windows 1.2.4 和 Linux 实际 Gemini Key 接入可用，不再要求其重复实测。发现旧界面把连接状态误作安装状态，未真正检查 App；模型数字是 `/v1beta/models` 过滤后的目录条目数，不等于实际验证的上游模型数量。
- 本地候选 Windows 1.2.5、Mac 1.1.17、Shell 1.0.3：Windows 读取常用安装位置及安装程序注册位置并核对实际 App 文件，不搜索硬盘；安装状态与连接状态独立，检测到 App 不显示下载，未检测到的提示不阻止已安装用户连接。切换标签及窗口回到前台复核本地状态。Mac 默认位置/已保存路径与 App 文件核对；Shell 保持有限位置、不递归搜索。
- 取消所有助手的未实测模型数量展示，保留原生模型查询和配置写入，不对每个模型发额外推理请求。Mac 终端菜单的 Key 与 Linux 命令一样可见。主站代码、模型路由、计费及原有接入协议均未修改。
- 本地 Go、10 项前端、4 项 Shell 终端交互测试已通过；Windows 交叉编译及真实官方安装程序自动识别的 Actions 回归待验证。先完成本修正，再分析 CLI，之后一起推送测试分支。

## Antigravity CLI 原生支持（同一候选，未发布）

- 用户在 App 实际接入成功后明确扩大目标为 App 与 CLI，仍排除独立 IDE 和编辑器扩展。Google 官方 [CLI 更新记录](https://antigravity.google/docs/changelog) 说明支持 `AGY_LLM_GATEWAY_*` 自定义企业模型网关；官方当前 CLI 1.5.18 安装清单已核对。
- 本机实际下载、SHA-512 核验并运行官方 Linux x64 CLI 1.5.18：相同 `AGY_LLM_GATEWAY_URL`、`API_KEY`、`WIRE_PROTOCOL=genai`、`MODELS` 成功，无登录要求；真实 `agy -p` 请求 `/v1beta/models/gemini-3.8-flash:streamGenerateContent?alt=sse`，Bearer 鉴权正确，含 Gemini 原生工具声明，收到模拟回复。
- Windows 1.2.5 复用用户注册表的相同四项环境变量，检测官方 App 和官方 `agy.exe`（标准安装目录及 PATH），一键配置同时生效；恢复同时撤销。Mac/Linux Shell 1.0.3 新增 `cli` 与 `cli-restore`，只配置当前用户终端启动环境，重新打开终端直接运行原官方 `agy`；无需 App、无需 sudo、不安装新的二进制。Mac/Linux App 与 CLI 设置及恢复独立；Mac GUI 网页导入仍为 App 入口。
- CLI 命令 `curl -fsSL https://actions-test.subdocs.pages.dev/install/antigravity.sh | bash -s -- cli`，恢复将最后参数改为 `cli-restore`。不影响原 App 命令。正式上线后域名替换为 `docs.usegoodai.com`。
- 本地官方 CLI 经准确候选 Shell 配置、重新打开 Bash、直接运行 `agy -p`（未强制模型）成功：原生 GET 模型列表与 POST 流式请求均正确。Shell 6 项与前端 10 项回归通过，CLI 配置可重复、坏 Key 不写入、恢复保留 App 与用户 Shell 设置。远端三平台同一候选实际 App/CLI 测试待执行，未宣称真实 CLI Key/计费已经验证。
- 不添加主站路由、计费或数据库读写逻辑；每次用户主动配置 CLI 仍读已有 `/v1beta/models` 一次，普通对话无新增请求。

- Shell 1.0.4：完整解析下载脚本后再执行命令，避免 `curl | bash` 在版本、恢复或缺少安装等提前退出时出现下载管道写入错误。1.0.3 未作为正式交付；候选复测以 1.0.4 为准。
