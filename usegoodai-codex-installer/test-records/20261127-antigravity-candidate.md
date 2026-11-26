# Antigravity App 原生接入测试候选（2026-11-27 JST，未正式发布）

## 范围与版本

- Windows 快速接入助手 1.2.4（基线 1.2.3）：新增 Antigravity 接入卡、v2 网页导入、当前用户 AGY 网关环境变量及恢复。无需管理员权限、不修改官方 App。旧 Codex、Claude、生图和国产模型业务保留。
- Mac 快速接入助手 1.1.16（基线 1.1.15）：网页链接直达；双击时选择软件，Antigravity 连接、打开、恢复通过终端菜单；仅将环境变量传入官方 App 进程。原 Codex 脚本保持。
- Linux 命令 1.0.0：新增 connect/open/restore/status/version，不新增图形助手；通过进程环境启动官方 App。
- 只读取现有 `/v1beta/models`，Bearer Key 鉴权；保留实际 Gemini 模型 ID，过滤非编程模型。不改主站后端、分组、计费、数据库。每次显式接入新增一次既有原生模型列表查询；普通推理请求零额外读写。主站由独立会话实施，契约 `usegoodai://import?v=2&app=antigravity&key=...&name=...`。
- 冻结程序及构建代号：`84f44728a8b8bb61737bf897e1f3706917b74bc4`；后续测试工作流不改程序代码或候选成品。候选来源 [三平台构建及实测 45849186242](https://github.com/youdaowudao/subdocs/actions/runs/45849186242)。

## 验收结果

| 系统 | 官方 App 2.35.2 配置、流式对话（模拟服务） | 成品入口 |
| --- | --- | --- |
| Windows 11 Enterprise 10.0.26200、ARM64 运行 x64 助手及官方 x64 App | 通过：当前用户注册表写入/恢复、实际官方 App 启动、原生 GET 模型列表及 POST SSE、实际 Electron 渲染界面回复。系统初始化隐私向导挡住前台，采用只在测试运行器上启用的本地 CDP 操作真正渲染的 App；未视为屏幕前台通过。 | 同一 EXE 成功建窗、注册 usegoodai://、把后续链接交给已开窗口（启动日志）；WebView2 调试端口不可用，新标签页可见反馈未核实。相同 EXE 的 --antigravity connect 经正式站假 Key 返回 401，无配置写入：[命令复核](https://github.com/youdaowudao/subdocs/actions/runs/45854159459)。未用 Windows Server；原生 x64 硬件和开始菜单重开后的环境继承待用户实际复核。 |
| macOS 15.8.2、arm64 | 通过：真实 App 窗口，系统 UI 操作发送 test 后显示模拟回复，原生模型路径及 Bearer 已核对。 | 整体签名和严格 codesign 验证通过；解压签名候选后系统链接直接进入 Antigravity 并拒绝假 Key。浏览器隔离标记打开显示 Apple 无法验证开发者的标准拦截（非“已损坏”）；运行器未完成系统“仍要打开”的人工批准，不能算批准后打开通过。 |
| Ubuntu 24.04 x64 | 通过：真实 App 窗口、实际点击发送 test、原生 SSE 和模拟回复。运行器需为官方 App 配好 Chromium sandbox 文件的权限，未使用 --no-sandbox；这不属于接入命令的权限要求。 | 精确 Linux 候选命令 version = 1.0.0，假 Key 经正式站返回 401、退出 1、未写配置。 |

- 证据 [三平台 App 原生验收](https://github.com/youdaowudao/subdocs/actions/runs/45849186242) 全部成功，含截图、请求日志：Windows [15134245633](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15134245633)，Mac [15133510606](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15133510606)，Linux [15132487050](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15132487050)。
- 精确成品入口 [45852416407](https://github.com/youdaowudao/subdocs/actions/runs/45852416407)：Mac、Linux 成功；Windows 前台及 WebView2 自动化未完成，已保存实际启动记录，另以精确 EXE 命令补测通过，不隐瞒限制。
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
| [Linux 1.0.0 TAR.GZ](https://github.com/youdaowudao/subdocs/actions/runs/45849186242/artifacts/15133685338) | `57eb6f642971b545e9030a42fe2e2c339e74fc1b4d9969b49c1f56b7ad01fc1d` |

组合本地候选 `下载成品/中转站快速导入工具_20261127-0035_Antigravity测试候选.zip`，13,280,391 字节，SHA-256 `8ff72f5586d54b45d4ca71c80e92712fb9fa7ed8c5d9f62ffb5909d944a7bb65`。核对 3 系统文件、版本、Linux 可执行权限、Mac 签名件和归档 CRC；各成品字节不变，使用说明分别放入对应目录。

## 发布边界

仅提交、推送固定 `actions-test`。正式站 `main/origin/main` 保持 `bff057b5159d7d82b7b43059afd42d06fc1d449f`；`docs/public/` 无差异。正式下载文件仍是旧版本，正式门禁的发布文件检查必然因候选版本与未替换的成品不符而失败（[45849186293](https://github.com/youdaowudao/subdocs/actions/runs/45849186293)，另两项既有门禁通过），未移除、跳过或放宽门禁。用户验收后才另行同步成品、执行正式发布门禁及上线，不将本次候选认作已发布。
