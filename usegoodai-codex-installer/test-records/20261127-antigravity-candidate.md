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

## 最终候选 App + CLI 验收（2026-11-27 JST，未发布）

- 用户已确认旧候选 Windows 与 Linux 实际 App 接入成功；本次修正后无需再请求用户重做。主站同事只读确认 `/v1beta/models` 可能为分组账号模型映射并集、混合账号列表、实际上游目录或内置回退目录；线上该分组配置未核实，不能断定此次 20 vs 4–5 的具体分支。若需限制实际对外模型，主站已有分组模型白名单；本次不改主站，助手不再显示数量。
- 最终源码提交 `cefd8093223533d65f01ce5d62743758edddf73e`，Windows 1.2.5、Mac 1.1.17、Mac/Linux Shell 1.0.4。[三平台完整实测 45952148628](https://github.com/youdaowudao/subdocs/actions/runs/45952148628) 全部成功。官方 App 2.35.2、CLI 1.5.18 均为真实程序，不是模拟客户端；仅服务端 Key 与回复为本地模拟。
- Windows 11 ARM 上 x64 官方 App 的自动检测在接入前实际识别 `C:\Users\runneradmin\AppData\Local\Programs\antigravity\Antigravity.exe`；新安装与注册表自定义目录识别回归通过，CLI 接入、真实 CLI 检测及当前用户注册表恢复通过。App 前台激活仍受运行器限制，实际 Electron 渲染窗口用 CDP 发送真实请求；不宣称物理前台验收。相同候选 EXE 实际 `--antigravity connect` 假 Key 返回正式 URL HTTP 401、无写入。
- Mac Apple 芯片、Ubuntu x64 的默认 App 入口实际发送对话；CLI 都通过真实 Shell 管道配置、重新打开 Zsh/Bash 并直接运行原 `agy -p`，无需 `--model`；Windows 真实 CLI 从助手写入的用户环境变量取得配置。三平台 CLI 请求均验证 Gemini `/v1beta/models/...:streamGenerateContent`、Bearer、原生工具声明及回复。Mac 签名候选网页 v2 链接假 Key 401 与签名校验通过；浏览器隔离标记实际打开显示系统「Apple could not verify」标准警告，非「已损坏」；运行器未完成「仍要打开」人工批准，未当作通过。
- 证据：[Windows](https://github.com/youdaowudao/subdocs/actions/runs/45952148628/artifacts/15176664912)、[Mac](https://github.com/youdaowudao/subdocs/actions/runs/45952148628/artifacts/15177332810)、[Linux](https://github.com/youdaowudao/subdocs/actions/runs/45952148628/artifacts/15177456508)。测试站 Shell 1.0.4 SHA-256 `d10baf28a4c08898d9d4105bbee4de0e9625f89f1e8721234b053934fe8933bb` 与源码一致。真实 CLI Key/计费尚未验证，不以模拟服务代替。
- 新候选：[Windows 1.2.5](https://github.com/youdaowudao/subdocs/actions/runs/45952148628/artifacts/15177057006)，EXE SHA-256 `cd307f35167269e71f8cf553745a837220c37796def037097aec0bdb6bd94407`；[Mac 1.1.17 签名包](https://github.com/youdaowudao/subdocs/actions/runs/45952148628/artifacts/15177028229)，SHA-256 `f6045dbcf8b8ea5613ef91ab39e0374c3dbabedd3cb57017645c564d37e41e9e`。本地组合 `下载成品/中转站快速导入工具_20261127-1534_Antigravity测试候选.zip`，10,598,452 字节，SHA-256 `caadd9fe933a02f35439888d84e3d48848ddc30af702dae1b9a0aab069d8a3f3`，仅 Windows 和 Mac，两者内容及 Mac 签名文件字节和权限与 Actions 产物一致；旧本地候选已被替换。
- 主线未发布，正式成品未替换，[既有门禁 45952148539](https://github.com/youdaowudao/subdocs/actions/runs/45952148539) 另外两项成功、发布文件检查因待发布候选与旧正式 ZIP 不一致失败，未绕过。正式上线须另行同步成品、运行正式门禁。仅测试分支部署预览。
- Bash（Linux）和 Zsh（Mac）新终端的真实 CLI 启动已验证；Fish 配置逻辑已实现，但当前没有 Fish 真机验证。Windows x64 硬件未测试，运行器为 Windows 11 ARM 转译。
- 回收本次本地官方 CLI 下载/解压、测试用户目录、临时证书及重复候选文件，共 407,969,445 字节（约 389 MiB），另删除被替换的旧候选 10,584,740 字节。保留最终 ZIP、预览脚本、验收记录、截图和请求日志。

## 正式发布准备（0.1.40，2026-11-27）

- 用户授权发布 App 与 CLI，确认既有真实 App 接入可作为同一 Gemini 原生网关的发布依据，无需其重测。真实 CLI 计费仍未核实。Windows App 已配置的用户环境可直接供新 CLI 终端使用；Mac/Linux App 的环境为进程级，CLI 首次需单独执行命令。
- 模型数量复核更正：用户明确表示当天返回 5–6 个模型。旧 1.2.4 源码只统计同一次 `/v1beta/models` 返回的去重、过滤后 ID，不生成新的 ID，不会把 5–6 个响应条目变成 20。无旧响应或用户保存的模型列表证据，无法证明 20 的实际来源，不能将主站可能存在的回退作为已确定原因。保留用户确认的取消数量展示，不更改模型目录及计费逻辑。
- 复用 `45952148628` 的精确候选 Windows 1.2.5 EXE、Mac 1.1.17 签名 App 和同一提交 Shell 1.0.4。正式 ZIP 中旧 Mac 2、3 工具文件及权限逐项一致，只有助手及使用说明变化；Windows 更新 JSON 同步；无 Linux 成品包。新正式附件名 `中转站快速导入工具_20261127-1544.zip`。新增[接入教程](/clients/antigravity)及 `antigravity.sh` 响应头、源码一致性测试。待正式签名与发布门禁通过后推送 main，上线后核对实际域名。

- 正式成品准备提交 `07dfba17daa0d60d87e348fb96e0e9993d6fd094`：[三项发布门禁](https://github.com/youdaowudao/subdocs/actions/runs/45954110703) 全部通过，App/CLI [复测](https://github.com/youdaowudao/subdocs/actions/runs/45954110787) 成功。Mac [整体签名与下载隔离测试](https://github.com/youdaowudao/subdocs/actions/runs/45954110659) 成功，合集中三 App、单独助手均通过严格签名校验；重新签名的两份 ZIP 与仓库逐字节一致，SHA-256 分别为 `0da02da28d510aa176bc4dd121a52bfe0dad6da635cbbaeb8acef35bda2ef117`、`f6045dbcf8b8ea5613ef91ab39e0374c3dbabedd3cb57017645c564d37e41e9e`。四份首次打开截图均为系统无法验证的标准拦截而非已损坏；运行器没有完成系统人工放行。
- 额外 Windows 全量回归发现原链接队列测试传入 nil service，而新增 Antigravity 初始化使用正式服务地址；修改测试 fixture 为与生产启动相同的非空服务，并覆盖 Antigravity 链接排队，未改生产源码或成品。重新运行当前提交的检查，不能用上一提交的门禁冒充本次结果。

## 正式发布完成（0.1.40，2026-11-27）

- 正式工具提交 `3a46b5f5a144116dd598f345bdac1a27676e93c2`：测试分支 [三项门禁](https://github.com/youdaowudao/subdocs/actions/runs/45954983136)、[Windows 全量及更新回归](https://github.com/youdaowudao/subdocs/actions/runs/45954983053)、[三平台 App/CLI 复测](https://github.com/youdaowudao/subdocs/actions/runs/45954983086) 全部成功；本地快进合并 main 后 [正式门禁](https://github.com/youdaowudao/subdocs/actions/runs/45955635662) 三项均成功、Cloudflare Pages 正式部署成功，未跳过门禁。成品与已签名的 07dfba1 逐字节一致。
- 正式域名重新下载并逐字节比对全部 HTTP 200：
  - [合集](https://docs.usegoodai.com/download/usegoodai-tools.zip)：15,117,680 字节，SHA-256 `0da02da28d510aa176bc4dd121a52bfe0dad6da635cbbaeb8acef35bda2ef117`，附件名 `中转站快速导入工具_20261127-1544.zip`，Windows 1 个 EXE、Mac 3 App（助手 1.1.17、生图 0.9.7、国产模型 1.0.3），无 Linux 包。
  - [Windows 1.2.5](https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe)：20,136,960 字节，SHA-256 `cd307f35167269e71f8cf553745a837220c37796def037097aec0bdb6bd94407`，更新 JSON 同版。
  - [Mac 1.1.17](https://docs.usegoodai.com/download/usegoodai-quick-connect-mac-arm64.zip)：2,514,261 字节，SHA-256 `f6045dbcf8b8ea5613ef91ab39e0374c3dbabedd3cb57017645c564d37e41e9e`。
  - [Shell 1.0.4](https://docs.usegoodai.com/install/antigravity.sh)：15,375 字节，SHA-256 `d10baf28a4c08898d9d4105bbee4de0e9625f89f1e8721234b053934fe8933bb`，UTF-8 文本与源码相同，正式域名实际运行 `version` 为 1.0.4。[正式教程](https://docs.usegoodai.com/clients/antigravity) HTTP 200。
- 35 项本地发布文件测试通过，隔离文档构建通过。真实 CLI Key/计费未核实，未要求用户重复测试；Mac 人工首次放行及 Windows 原生 x64 硬件限制如上。主站后端不变；模型数量历史差异实际来源仍未取得证据。
- 回收本次隔离构建输出 138,648,881 字节、重复 Mac 候选与合集 17,632,588 字节，以及正式发布替代的测试合集 10,598,452 字节。保留正式下载文件、在线校验 JSON、签名截图和 Actions 记录。

## 文档入口补充（0.1.41，2026-11-27）

保留已发布 `/clients/antigravity` 的 App/CLI 独立教程，顶部导航与 Codex、Claude 并列，首页及快速开始增加直达；压缩正文操作步骤，恢复官方登录折叠。窄屏使用既有折叠菜单，修正模糊头部导致浮层高度为零。隔离文档构建及 6 个屏幕宽度、首页/快速开始真实浏览器入口均通过。仅调整文档与导航样式，Windows 1.2.5 / Mac 1.1.17 / Shell 1.0.4 及下载文件逐字节保持不变，沿用既有工具门禁，不重新构建工具。
