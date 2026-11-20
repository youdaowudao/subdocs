# Windows 中文化执行入口

`chinese.ps1` 由 `quick-connect/build.py` 从已发布的 `install/chinese.ps1` 原字节复制，打包前与站点副本核对；不在这里修改中文化算法。

`run.ps1` 只负责可见 PowerShell 窗口的转录、结果判断、成功后五秒倒计时与失败保留。日志预置 UTF-8 BOM，保证 Windows PowerShell 5.1 追加中文时使用 UTF-8。

原脚本部分失败分支输出 `[失败]` 后返回，退出码可能仍为零；外层以最后一个明确结果为准，异常、缺少成功结果或日志失败均不自动关闭。
