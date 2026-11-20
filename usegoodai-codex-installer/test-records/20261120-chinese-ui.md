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
