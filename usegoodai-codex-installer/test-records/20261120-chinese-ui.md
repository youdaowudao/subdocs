# Windows 中文化按钮接入 1.2.1

记录版本 1.0.0 · 2026-11-20，候选未发布。

原有能力：Windows 助手 1.2.0 的 UI、运行互斥及日志目录；已上线的 Windows 中文化 1.1.6。新增仅为末尾按钮、独立可见 PowerShell、按次转录和成功五秒关闭。数据与配置沿用原脚本处理，未增加服务接口、密钥配置、缓存算法或数据库修复。

按钮文案为「一键中文化（没有梯子才需要）」，位于生图和国产模型入口下方。失败时窗口保留；内层脚本输出失败后可能返回零，外层按明确结果判断，不把零退出码当成功。转录文件预置 UTF-8 BOM，避免 PowerShell 5.1 追加中文时落为 ASCII。新控制台不继承 GUI 已重定向的标准句柄，保证用户看见真实输出。

## 候选与测试范围

- 中文化原始字节 SHA-256：`33968270a2c26e6aa21946a5beb2a594982a930626492e7bbf125a5f82a3fabd`；上层、站点及内嵌副本一致，不重跑已通过核心网络矩阵。
- 本地新增打包/日志/错误处理测试和相关既有 Go 测试已通过；资源测试首次读到旧 1.1.16 临时成品而失败，已改为明确核对本轮候选，不算产品缺陷或验收通过。
- Windows 11 采用既有 Windows 11 ARM 运行器，发布 x64 EXE 经系统转译。Windows 10 使用 Actions Linux 主机承载的真实 x64 Windows 10 Enterprise 评估系统，测试在交互登录桌面执行，断言 ProductType=1、系统名及非 Session 0，不以 Linux 主机或 Server 代替。
- 当前两个桌面验收尚未执行，不能宣称完成。范围：真实点击候选 EXE、入口位置、可见控制台、成功倒计时、失败保留、重复/开着/关闭时运行、日志与中文路径、手动关闭恢复及无残留。
- Windows 10 虚拟机使用固定镜像摘要 `dockurr/windows@sha256:16fd7c39a3e48bb946d29c59dc6015942e5b900a1fa5d7e5552053bfc48ee2ea`，指定 10e，仅允许一次性 Actions Linux 运行器创建；环境启动失败与产品测试失败分别记录，不索要真实 Key。
- 合集只替换 Windows EXE 与简短说明，所有 Mac 文件内容与权限保持逐项一致；不重新签名或重测未变 Mac 成品，保留既有必要三项发布门禁。

## 依据及限制

PowerShell 转录与编码依据：[Microsoft Start-Transcript](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.host/start-transcript?view=powershell-5.1)。独立控制台依据：[Microsoft Process Creation Flags](https://learn.microsoft.com/en-us/windows/win32/procthread/process-creation-flags)。Win10 环境依据：[Dockur Windows](https://github.com/dockur/windows)及[微软 Windows 10 Enterprise 评估系统](https://www.microsoft.com/en-us/evalcenter/download-windows-10-enterprise/)。

真实账号、真实中转鉴权及计费不在本轮验证范围。新机迁移已取消，迁移核查私有资料仍保留；本轮不迁移、删除或重发其它项目资料。

## 首轮环境问题与补测

- 候选提交 `449a8bc` 的三项既有发布门禁均通过：[运行 44757275991](https://github.com/youdaowudao/subdocs/actions/runs/44757275991)。
- Windows 11 按钮已调起 PowerShell，但运行机首次隐私设置页覆盖桌面，自动回车未送达；截图确认，首轮不计通过。仅在验收脚本复用现有 `Complete-PrivacyScreen` 完成运行机初始化，产品 EXE 与内嵌核心均未修改。
- 按钮验收改为手动选择系统，避免已通过组随无关记录提交反复运行；不新增发布门禁。

- 既有助手回归 `44757276580`：启动、生图升级、窗口自更新、画图导入及本轮新增 Go 用例通过；Claude 两项旧 PS5.1 检查超时、国产模型检查在管理记录出现后立即读取配置而失败。源码确认现有事务先提交管理记录再提交配置；验收改为等待界面显示“已导入”后读取，不改业务脚本。仅补测这三项，其余成功项不重跑。

- 首轮 Win10 已实际进入微软 Windows 10 企业版 19045 / AMD64 / Session 1，候选窗口与 PowerShell 中文输出可见；验收发送回车前未等待前台切换而失败，改为实际点击目标标题栏并确认前台后发送按键。失败记录不计通过。
- Windows 11 ARM 补测仍停在可见控制台检查，截图依旧为系统隐私页，记录为空；继续保留未通过，不当作产品成功。复用已启动成功的 VM 验收方式，补真实 Windows 11 x64 桌面，两个系统均断言桌面版和交互会话；未使用 Server。

- `44759032659` 的 Claude 双配置写入补测通过；旧命令 PS5.1 仍超时，新增仅用已发布 1.2.0 对照同一失败用例以判断是否本轮引入，不扩大修复范围。国产模型实际配置已写对并保留原模型与策略，但等待“已导入”文本未完成；收窄为等待整个文件事务提交后核对现有断言，保留界面等待未通过记录。

- 国产模型事务补测 [44760475545](https://github.com/youdaowudao/subdocs/actions/runs/44760475545) 通过，内嵌脚本哈希 `91cdcd8d…297e42`，10 个国产模型与两个 GPT-6.2、原模型/策略/Key 均核对。
- 旧版 PS5.1 对照 [44760469344](https://github.com/youdaowudao/subdocs/actions/runs/44760469344) 19.02 秒通过，不能认定新版超时为既有问题。只给这一个失败用例补请求计数和引擎开始标记；测试外层 60 秒小于被测入口允许的 90 秒执行时间，改为 120 秒观察，产品超时及代码均不改。
