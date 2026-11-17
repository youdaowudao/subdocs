# Windows Claude 一键接入命令

版本：Windows 快速接入助手及命令 1.1.16。日期：2026-11-17。

## 本次增量

- 原有能力：Windows 助手接入 Claude 桌面版，并可在确认后配置默认位置安装的 Claude Code CLI；已有密钥检查、模型筛选、备份、配置合并与恢复。
- 修改已有行为：桌面版接入成功后，自动配置已安装的 CLI；没有 CLI 时不提示、不创建 CLI 配置。
- 新增入口：`install/claude.ps1` 下载同一个助手，调用 `--claude-connect`，经私有标准输入传 Key，经 UTF-8 JSON 标准输出接收结果，无需窗口或 WebView2。复用 `Service.ConnectClaude`，不重写接入业务逻辑、不新增服务端接口。
- 版本核对：Windows 源码、EXE 资源、窗口、命令结果、安装脚本均为 1.1.16；Mac 专用 `MacVersion` 保留 1.1.14，Mac 下载包及合集内三个 App 原文件保持一致；生图 0.9.6、国产模型 1.0.2 不变。
- 仅 Windows，以已安装 Claude 桌面版为前提；不增加 CLI 独立模式、客户端选择菜单、Mac 或 Linux Claude 接入功能。CLI 检测范围沿用默认原生安装位置和 npm 默认安装位置。
- 教程增加一条命令；CLI 教程引用同一入口。无数据库迁移、后台配置或活动启用步骤；发布后由固定脚本地址直接提供。

## 验证范围与结果

- 本地：接入核心测试通过，覆盖只装桌面版、同时安装 CLI、CLI 配置失败时保留桌面版并重试、配置保留、重复执行、拒绝无效请求和密钥不出现在命令输出。助手 Go 全量通过；137 项站点测试全部通过（0 跳过），桌面打包 7 项通过，文档站构建通过；Windows 测试程序交叉编译通过。
- Windows Actions：Windows Server 2022、2025 上，真实发布 EXE 的管道入口、PowerShell 5.1/7 的 HTTP 下载管道、中文空格路径、临时文件清理均通过；成功写入用例验证桌面版配置、CLI 自动接入、旧设置保留和备份；没有 CLI 时不创建其配置、不在结果中提示 CLI。
- Windows 成功写入测试使用原发布 EXE、临时用户目录、假 Key、本地 HTTPS 模拟接口。原程序仍使用正式 API URL；测试通过本地 CONNECT 代理定向到模拟服务，将临时 CA 加入一次性运行器的 LocalMachine 根证书库，测试后删除。此配置仅属于测试，不进入发布程序。
- 三项既有发布门禁、Windows 窗口回归：工具提交 `9cece4e47bd3ae22177e8f3d1a4f4afbee152ccc` 全部通过。
- 未验证：真实中转鉴权、计费、上游连通性、Claude 桌面版实际新建对话、真实 Claude CLI 发模型请求，以及客户真实 Windows 环境。配置目录夹具和 Go 单元测试不记为真实 Claude 客户端端到端验收。

工具提交：`9cece4e47bd3ae22177e8f3d1a4f4afbee152ccc`。成品哈希见下方；后续仅补记测试结果的文档提交复用相同完整工具文件的检查。

## 候选 1.1.15 成品

合集文件名：`中转站快速导入工具_20261117-1334.zip`。

- `usegoodai-tools.zip`：`bbfda2fa68542b38c32867f5a63b611ad1fe1a25d51b6896f7e49e07e3e3c5b5`。
- `usegoodai-quick-connect-windows-x64.exe`：`66ce9b5955e6d841f2cfe4189cd21cee2fcd89546e427e66275a7567a5a7f10f`。
- `usegoodai-quick-connect-mac-arm64.zip`：`1b313bbb599a4c28f660e09422ba9595d2ee83efb27864f793cf13a9af1b44b9`。

Mac 下载包哈希与 1.1.14 原版一致；合集内 Mac 所有文件逐项比较一致。

## 候选 1.1.15 的失败与修正

[第一次 Windows 测试](https://github.com/youdaowudao/subdocs/actions/runs/44018451149) 在 Windows Server 2022、2025 上发现：PowerShell 5.1 标准输入带 UTF-8 BOM，命令未解析请求；PowerShell 7 已到达正确业务分支，但测试误把 PowerShell 自身缓存目录当成命令残留；成功写入测试依赖的证书 PSDrive 未加载。

1.1.15 没有作为主线下载版本发布，后续修正合并到 1.1.16。1.1.16 的命令入口兼容 BOM，脚本使用标准 StreamWriter 写请求；证书夹具改用 .NET 证书库，临时文件检查只核对本工具文件。改动后重新执行本次相关测试。

## 1.1.16 成品

合集文件名：`中转站快速导入工具_20261117-1344.zip`。

- `usegoodai-tools.zip`：`a368c3802cef8c934010d0a459650c25f198b0558e7fa923c8f4848717303332`。
- `usegoodai-quick-connect-windows-x64.exe`：`55057bf907441fc228884abea5d954a6d8e51a8ce2136681eeb52d1f37809a49`。
- `usegoodai-quick-connect-mac-arm64.zip`：`1b313bbb599a4c28f660e09422ba9595d2ee83efb27864f793cf13a9af1b44b9`。

测试夹具修正：CurrentUser Root 的证书操作在托管 Windows 上等待未返回（具体系统对话框未核实）；改为一次性管理员运行器的 LocalMachine Root，并为证书操作增加 20 秒超时，Go 全量测试增加 4 分钟超时和详细日志。证书准备需要的运行器权限不记为客户普通账户权限已验证。发布程序和安装命令不执行证书操作，1.1.16 EXE 与脚本哈希保持不变。

## 通过的 Actions 记录

- [Windows Server 2022 / 2025 原生 Go、PowerShell 5.1 / 7、窗口与升级回归](https://github.com/youdaowudao/subdocs/actions/runs/44020451557)：通过，工具提交 `9cece4e`，发布 EXE SHA-256 与本记录 1.1.16 成品一致。
- [同一提交三项既有发布门禁](https://github.com/youdaowudao/subdocs/actions/runs/44020451428)：Mac 国产模型导入门禁、国产模型导入回归、发布文件检查全部通过。没有新增必需检查或分支保护。
- [Windows 11 ARM 打开稳妥性](https://github.com/youdaowudao/subdocs/actions/runs/44019407137)：通过，测试同一 1.1.16 EXE；记录为 ARM 系统下运行 x64 成品，不记为 Windows 11 x64 原生 CLI 端到端测试。
- [Mac 原签名成品打开](https://github.com/youdaowudao/subdocs/actions/runs/44019407187)：通过，Mac 发布文件未改动。
- [Mac 构建流程](https://github.com/youdaowudao/subdocs/actions/runs/44019407376)：通过；只用于核对保留 Mac 1.1.14 后构建流程仍有效，没有用该产物替换正式 Mac 下载。

主线工具提交 `9cece4e` 的[三项发布检查](https://github.com/youdaowudao/subdocs/actions/runs/44020910813)再次全部成功。测试记录补记只修改 Markdown，完整工具文件的路径、类型、权限和内容与该工具提交一致；正式站按既有规则复用该提交检查。
