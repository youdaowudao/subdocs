# 生图 0.9.4 与助手 1.1.11：VPN 系统代理发布测试（2026-11-11）

记录版本 1.0.0；生图 0.9.4（子项目 usegoodai-imagines-tool 提交 ae030b2）、助手 1.1.11；国产模型导入保持 1.0.1。

## 问题与原因

Mac 客户开着 VPN 生图失败，诊断称“命令仍在沙箱内、放行规则没有生效”，反复重启 Codex 无效。在 GitHub 运行器上用官方 Codex 复现：放行规则生效，命令已在沙箱外；V0.9.3 只读代理环境变量、不读系统代理，VPN「系统代理」且直连不通时绕开 VPN 超时，诊断把所有连不上网都误报为规则没生效。详细过程见子项目 `test-records/20261111-vpn-proxy/复现与验证.md`。

## 复现（V0.9.3）

- [Mac 复现](https://github.com/youdaowudao/subdocs/actions/runs/42956033807)：官方 App 26.1106.51428 内置后端 0.167.0-alpha.4.1；Codex 内两次新启动均不在沙箱、能写桌面，约 30 秒超时并误报规则没生效。
- [Windows 复现](https://github.com/youdaowudao/subdocs/actions/runs/42959979045)：npm 官方 codex-cli 0.167.1；同样在沙箱外、约 22 秒超时并误报。
- 默认网络下 [Mac 8 种组合](https://github.com/youdaowudao/subdocs/actions/runs/42953619084) 规则全部生效；TUN 模式下 V0.9.3 也能连通。

## 候选验证（V0.9.4，两轮代码审查后）

- [Mac](https://github.com/youdaowudao/subdocs/actions/runs/42961915021)：不开 VPN 8/8 正常；系统代理 VPN 两次新启动 1.0～1.7 秒连通；TUN 连通；沙箱对照组报“Codex 沙箱（seatbelt）内，放行规则没有生效”。
- [Windows](https://github.com/youdaowudao/subdocs/actions/runs/42961914915)：系统代理 VPN 两次新启动 1.5～1.8 秒连通。
- 两平台 VPN 退出、PAC 模式、没有代理时的诊断分别给出打开 VPN / 关闭系统代理、改用系统代理或 TUN、打开系统代理或检查网络的指导，不提放行规则、不让重启。

## 发布文件

- 网站 0.9.4 程序、SHA256SUMS、latest.json、在线安装入口与子项目构建逐字节一致；上一稳定版 0.9.3，删除 0.9.2。正式程序与候选同源但构建参数不同（不写入 VCS 信息），故本 PR 新增的“生图 VPN 系统代理验证”直接对本次发布的程序复核。
- 合集 `中转站快速导入工具_20261111-1418.zip`：32 个条目，结构与上一版相同；Windows 助手 1.1.11 与下载 exe 一致并内嵌 0.9.4 Windows 程序；Mac 依次 1.1.11 / 0.9.4 / 1.0.1，生图 App 内程序即网站 0.9.4 Mac 版，第三个 App 全部条目、权限与时间与上一版一致；可执行权限保留。
- Windows 助手由本机交叉编译，`desktop/build.py` 复建结果逐字节一致；Mac 助手启动器来自 [Mac 构建](https://github.com/youdaowudao/subdocs/actions/runs/42964432250)，本地打包与该运行产物内容一致。
- [四平台原生升级 0.9.3 → 0.9.4](https://github.com/youdaowudao/subdocs/actions/runs/42964432296) 成功。最终提交的三项既有门禁、Windows 实际窗口测试与 VPN 验证见 [本 PR 的检查](https://github.com/youdaowudao/subdocs/pull/5/checks)。

## 未验证

- 客户真实网络、真实中转鉴权、计费与生图；完整 Codex 桌面图形界面任务。
- Windows TUN 模式；PAC 模式不支持（工具给出切换指导）。
