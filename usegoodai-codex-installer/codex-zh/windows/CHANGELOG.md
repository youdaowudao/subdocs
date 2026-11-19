# Codex 桌面版中文化版本记录

## 1.1.0 · 2026-11-20

- 修复 1.0.4 在没有梯子的电脑上失败：首次运行报「刷新后 Codex 未读取到已启用的语言开关」，再次运行报「Codex 调试调用失败：Runtime.evaluate」，界面仍是英文。原因是 1.0.x 自行改写了上游流程，额外要求刷新后 15 秒内 Statsig 就绪并实时返回开关；没梯子时 Statsig 约 32 秒才就绪。之前的测试只在能联网的海外机器上做过，测不出来。
- 改为照搬上游 `current-key` 两个脚本（GitHub `feb1239c5acf`），文件名不变，只改四处并以 `# UseGoodAI：` 标出：
  1. 关闭进程复用 `install/codex.ps1` 的 `Stop-RunningClients`，关完沿用上游做法等进程列表清空（最多 10 秒）。复制来的 `Get-OwnProcessIds` 加启动时间判断，避免把复用了已退出进程编号的 ChatGPT.exe 当成父进程而漏关。
  2. 取消自动重启，写完缓存后关闭调试实例，提示用户自己打开 Codex。
  3. 核心脚本发布时嵌入，不再运行时从 Gitee 下载。
  4. 强制结束前先结束页面进程并等 2 秒。实测上游直接强制结束会丢失尚未写入磁盘的缓存，提示成功但重开仍是英文。
- 不再写 `config.toml`。删除 1.0.x 的 `chinese.ps1`、`desktop.ps1`、`config.ps1`、`core.ps1`。Mac 版未改。
- 发布文件 SHA-256：`06faa4574ba728cfc742254f125bad9f0bd3b2a8cfeafa5c21962a68f655a9cb`。
- 测试：Windows 11 ARM64、原生 PowerShell 5.1、官方 Codex `26.1111.9664.0`，按用户操作用 `irm … | iex` 运行。网络分三种：连接挂起（模拟被墙）、完全断网、正常联网。Codex 状态包括 API Key 接入后的工作界面和未登录的登录页。每组依次在 Codex 开着、再次运行、Codex 未开时各运行一次，完全断网另加连续压力运行。最终一轮 9 组共 55 次运行全部成功；每次都确认上一次写入的缓存还在，重开后界面为中文。关闭正在运行的 Codex 不超过 1 秒，无残留调试进程或端口。旧版 1.0.4 在连接挂起时 3 次全部复现用户报错。[实测记录](https://github.com/youdaowudao/subdocs/actions/runs/44593724628)
- 测试中发现并已修复：上游直接强制结束丢缓存（落盘对比实验：直接结束 2/2 丢失，先结束页面进程 3/3 保留）；复用关闭函数后进程列表短暂残留；进程编号复用导致漏关。
- 未验证：Windows x64 实机、Windows 10、中国大陆真实网络、CC Switch 自动拉起 Codex。Windows 未在 Codex 中选过语言的用户界面跟随系统语言；英文系统上仍显示英文，以中文界面语言启动时为中文。

## 1.0.4 · 2026-11-19

- 网站发布脚本改用无 BOM 的 UTF-8，公开命令恢复为 `irm … | iex`。本地源码入口和中文化逻辑保持原样。
- Windows PowerShell 5.1 的短命令与原始文件哈希验证记录。 [复测记录](https://github.com/youdaowudao/subdocs/actions/runs/44515630170)

## 1.0.3 · 2026-11-19

- 保留项目已有的强制关闭方式，在原有等待时间内同时确认进程已退出和系统查询结果已更新。
- Windows 11 ARM64 原生 PowerShell 5.1 通过单文件 HTTP 下载与执行复测。已打开的官方 Codex 退出，中文化后正常重启，临时端口释放，安装文件与签名哈希一致。发布文件 SHA-256 为 `9f1a9d1cd643a29f36d7313d214d57c1e364601a62667d2d513f6e41d6dccc26`。 [Windows 实测](https://github.com/youdaowudao/subdocs/actions/runs/44508459203)
- 测试提交的三项现有发布检查通过。正式站已发布于 `ea8c872`，线上脚本 SHA-256 一致。 [发布检查](https://github.com/youdaowudao/subdocs/actions/runs/44508461762)

## 1.0.2 · 2026-11-19

- 发布 Windows 微软商店版 Codex 中文化独立命令 `/install/chinese.ps1`。单文件由 1.0.1 的关闭、配置和缓存源码生成，运行只下载这一份发布脚本。
- 候选未发布。Windows 实机使用 CRLF 副本完成运行，原始字节的复测遇到退出检测过早的问题。 [复测记录](https://github.com/youdaowudao/subdocs/actions/runs/44507815341)

## 1.0.1 · 2026-11-19

- 开头关闭 Windows 官方 Codex 桌面版改用项目既有的强制结束与退出检查方式，保护当前脚本及其父进程。修复已打开 Codex 时只关窗口、进程未退出导致脚本停止的问题。
- Windows 11 Enterprise ARM64 和 PowerShell 5.1 复测通过。官方 Codex `26.1111.9664.0` 已打开时，旧进程 5968 退出，临时调试进程 8456 只监听本机地址，正常重启为进程 2748，临时端口已释放。重启窗口截图显示登录页为简体中文，官方程序与签名文件哈希一致。 [Actions 记录](https://github.com/youdaowudao/subdocs/actions/runs/44504696779)
- 本地候选，未发布。本轮复测关闭与重启流程。登录后的工作区和 Windows x64 尚未验证。

## 1.0.0 · 2026-11-19

- Windows 微软商店版 Codex 桌面应用的首个本地候选版。入口、Windows 启动流程和缓存核心均在本目录。运行时不依赖上游仓库。
- 开头请求正在运行的官方桌面程序正常退出。临时选择本机端口，确认调试端口属于本次启动的实例，写入并回读当前客户端的语言缓存。当前键尚未创建时，沿用上游补建缓存的方式。
- 只写用户配置中的 `desktop.localeOverride = "zh-CN"`，保留现有文本并在有改动时备份。已有缓存结构未知时停止。
- 本地验证通过：PowerShell 解析与 C# 编译、商店清单两种路径写法、TOML 字段保留和备份、缓存写入与首次补建，以及本机调试连接、进程清理顺序和启动冲突的模拟用例。
- Windows 11 Enterprise ARM64、系统 PowerShell 5.1 实测官方签名 MSIX `26.1111.9664.0`。从已退出状态运行时，本机调试端口只监听回环地址，正常重启后释放。自带 Codex CLI `0.169.1` 在修改前后均完成本地模拟任务。安装包身份、签名文件、桌面程序、CLI 和 `app.asar` 的哈希一致。
- 窗口截图显示登录页从英文变为简体中文，普通重启后保留。WireGuard 测试虚拟网卡和独立路由启用，同时给脚本进程设无效代理后，语言验证和端口释放同样通过。测试未接入真实 VPN 网关。
- 未通过项是 Codex 已运行时，正常关闭请求后进程仍在，脚本停止。Actions 的界面自动识别没有读到登录页文字，中文结论来自人工核对前、中、后窗口截图。登录后的工作区、正式商店升级、CC Switch 和 Windows x64 尚未验证。未发布。[Windows Actions 记录](https://github.com/youdaowudao/subdocs/actions/runs/44493828508)
- 上游参考：Gitee `zhenglei410/codex-i18n-cache-seeder` 提交 `61ec628c9b7652be63ee544ba392aee79e546183`。
