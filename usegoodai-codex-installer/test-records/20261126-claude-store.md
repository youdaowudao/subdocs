# Windows Claude 微软商店安装检测修复

版本：Windows 助手 1.2.3（2026-11-26，候选，未发布）。Mac 助手 1.1.15 及其它工具不变。

## 缺陷及增量

- 原有功能：窗口 Claude 页、网站导入链接与 `install/claude.ps1` 共用 `Service.ConnectClaude`，检查密钥与模型、备份写入第三方配置、关闭桌面版、自动接入已安装的 CLI、恢复官方登录。
- 缺陷：原 `packageDir` 只按 `%LOCALAPPDATA%\Packages\Claude_*` 判断安装；进程路径也只认 `WindowsApps\Claude_*`。官网安装包是 `Claude_pzs8sxrjxfjjc`，微软商店产品 [9P6K58THS811](https://apps.microsoft.com/detail/9P6K58THS811) 的官方目录（CN、US、JP 均实查）提供 `AnthropicPBC.Claude_fnn82j28hfe8t`，ARM64/x64 共用这一包家族。客户实际包身份未采集；旧代码的覆盖缺陷已确认。
- 增量：用 `GetPackagesByPackageFamily` 查询当前用户已注册的两个官方身份，注册成功但目录未创建也能解析；单次接入/恢复复用同一检测结果。查询错误/两个安装渠道冲突不猜测、不写配置。已有残留目录不会误判安装，卸载后的恢复仍可清理公共和已知包配置。配置模板、备份/回滚和 CLI 接入不变。
- 关闭进程同时校验可执行文件在官方 WindowsApps 包安装目录内与进程的包家族身份，避免独立 CLI 继承桌面版包身份时被误关。独立代理审查（gpt-6.2-sol/xhigh）已提出该风险并采纳；真实运行条件尚待验证。
- 窗口仅增加检测失败文案。PowerShell 下载、密钥传输和协议沿用原 1.1.16 脚本；无服务端、数据迁移、计费或配置启用改动。

## 候选及验收范围

- Windows x64 EXE SHA-256：`e4be6e827cde6ddd4ebd4b1057525e2e3eb252f23710ebca52d2847307a00447`，20,021,248 字节。
- 合集候选 `中转站快速导入工具_20261126-1552.zip` SHA-256：`769ac3c75a1d4f2b9472e070dcd80f400300873d013887f21723b62bc20213eb`。只替换 Windows EXE；Mac 全部 ZIP 条目的真实内容及权限逐项保持，独立 Mac 下载包保持。
- 本地单元测试包含双包无数据目录、残留目录、查询失败、双包冲突、安装身份固定、卸载恢复、外部 CLI 路径和旧接入逻辑。实际 Windows 命令和进程 API 需 Windows 桌面验证，不能把交叉编译或目录夹具当成真实验收。
- 本地结果：指定候选 EXE 的 `go test -count=1 ./...` 全部通过（接入核心、助手、Mac 共用回归及 PE 版本资源）；Windows x64 两个测试程序交叉编译通过；34 项脚本、下载包、版本清单与发布门禁逻辑检查全部通过。PowerShell 验收脚本语法和 Python 模拟接口语法通过。旧缓存中的 1.1.16 PE 曾使首次资源测试失败，指向本次成品后通过，未把旧成品算成新版本验证。
- Windows 11 ARM 附加验收按官网和 Store 两渠道分别尝试真实注册、首次打开、候选 EXE 配置写入、关闭/重开及本地模拟对话。原生 x64、真实客户配置、真实中转请求及计费未验证；不使用真实 Key。既有三项发布门禁不变。

正式主线未推送；验收结果待补记。

第一次 Windows 渠道验收 [45771501649](https://github.com/youdaowudao/subdocs/actions/runs/45771501649)：Store 分支的无安装测试通过；安装阶段发现 Windows 11 ARM 托管机没有 `winget`，无法进入真实客户端验收。按微软官方 WinGet 安装说明补齐一次性测试机环境再重试，不改产品 EXE 或成品。候选 `253646c` 的三项既有门禁 [45771501557](https://github.com/youdaowudao/subdocs/actions/runs/45771501557) 均通过。

第一次 Windows 助手全量 [45771501566](https://github.com/youdaowudao/subdocs/actions/runs/45771501566)：四个新测试的 PowerShell 独立参考查询均在 30 秒超时，非产品原生查询失败；其它 Go 核心测试、PE 资源检查和后续窗口验收通过。改为独立 Windows PowerShell 测试步骤读取真实注册信息一次并提供测试期望，不将该数据注入生产程序；未安装测试还阻断假 Key 访问真实 API。此次仅改测试夹具和工作流，成品哈希保持不变。另 [45771501492](https://github.com/youdaowudao/subdocs/actions/runs/45771501492) 助手打开稳妥性和 [45771501601](https://github.com/youdaowudao/subdocs/actions/runs/45771501601) 原 Mac 签名成品打开成功。

第二次渠道验收 [45772311507](https://github.com/youdaowudao/subdocs/actions/runs/45772311507) 的 Store 分支：Windows 11 Enterprise 26200 ARM64；官方 WinGet 成功安装商店产品 `AnthropicPBC.Claude_6.28899.6.0_arm64__fnn82j28hfe8t`。首次打开前实际注册检测和候选 EXE 写入通过；真实 App 打开、候选自动关闭、当前用户配置写入、真实 App 重开均通过。重开后模拟网关日志出现 `/v1/messages`，证实客户端读取了测试接入配置；并非成功手动新建对话。桌面截图显示系统首次使用的隐私设置遮挡窗口，前台检查失败，手动新建对话未验证。复用已有 Windows 桌面验收的首次使用设置处理；用显式测试消息区分启动健康检查与用户实际对话。证据保存在 `.git/local-archive/claude-store-20261126/run-45772311507/store/`。全部运行使用相同 EXE 哈希 `e4be6e827cde6ddd4ebd4b1057525e2e3eb252f23710ebca52d2847307a00447`。
