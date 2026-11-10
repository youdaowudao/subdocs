# 生图升级测试（2026-11-10）

记录版本 1.0.0；候选生图 0.9.3、助手 1.1.7；国产模型导入保持 1.0.1。

生图完整源码提交：子项目 usegoodai-imagines-tool 的 58cbd0b。源码、VERSION、release_revision.go、四个平台程序及 SHA256SUMS 已核对；从所属子项目手动迁移到文档站，保留当前版和上一稳定版 0.9.2。

本地：生图 Go 全量测试、Python 63 项通过。助手覆盖旧版/缺 Key 状态、跳过凭据检查、保存原 Key、显式换 Key 的 Go 回归和真实前端按钮测试。Linux 本地原生升级通过。Apple 芯片 Mac、Intel Mac 的原生升级在 [候选 Actions](https://github.com/youdaowudao/subdocs/actions/runs/42764880335) 通过，使用系统 Bash 3.2。Windows PowerShell 首轮测试继承了 PowerShell 7 的模块环境，已改为直接从系统 PowerShell 5.1 运行；原生窗口测试首轮测试路径多退一层，已修正并复验。

原生测试使用临时假 Key、中文空格 CODEX_HOME；下载由本地模拟，真实原生安装程序、原公开脚本中的 SHA 校验与文件写入保留。覆盖保存/缺失/空/全空白 Key、显示旧版本、坏下载不改旧文件、恢复重试、重复运行不下载、首次空输入不循环、不改 Codex 配置。

真实中转鉴权、计费、生图、Mac 首次系统授权、完整 Codex 桌面新任务未验证。按钮自动测试目前是执行真实前端代码，不能称为 Windows 实际窗口验收。

合集：`中转站快速导入工具_20261110-1458.zip`；SHA-256：`3f1219e1e48ea61383224b59781618c0f895156a5f72f1f9a1dbbc61ff59a4bc`。合集内 Windows 助手 1.1.7，Mac 依次 1.1.7 / 0.9.3 / 1.0.1；第三个 App 与上一版逐字节保持一致。

[Mac 助手原生构建与链接测试](https://github.com/youdaowudao/subdocs/actions/runs/42764880239) 通过，打包使用该运行生成的 1.1.7 启动器。发布文件与前端回归 32/32、桌面包装检查 7/7 通过。
