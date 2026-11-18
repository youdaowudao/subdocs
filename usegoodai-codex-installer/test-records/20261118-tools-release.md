# 生图导入与 GPT-6.2 国产模型工具验收

日期 2026-11-18。国产模型导入 1.0.3，Windows 接入助手 1.1.19，Mac 接入助手 1.1.15。独立生图程序 0.9.6 未改源码或内置程序。两项更新使用同一份合集，其他网站业务配置无改动。

## 本地验证

- 从 [官方 Codex 0.170.0](https://github.com/openai/codex/releases/tag/rust-v0.170.0) Linux x64 安装包执行 `codex debug models --bundled`，归档 SHA-256 与 GitHub 发布记录相符。源快照 14 个条目，SHA-256 为 `62b6f557b7d01093323249b38f3237482c704345961596c5c57795d89e30c381`。
- 真实 Codex 0.162.1 和 0.165.0 分别运行 `model/list`，传 `includeHidden: false`。Shell 和 PowerShell 各覆盖无缓存、旧缓存、旧 1.0.2 覆盖与重复导入，共 16 组通过。两个 GPT-6.2 各出现一次，10 个国产模型和自定义模型可见。原默认 6.1 Sol、服务地址、Key 和其他配置保留。PowerShell 这部分在 Linux 上运行 Windows 脚本，原生 Windows 界面另验。
- 国产模型全量回归 53 项通过，既有配置恢复、原缓存优先级、失败保护和卸载通过。6 项生图界面回归与助手 Go 全量通过。测试使用独立目录、假 Key 和模拟服务。
- Windows EXE 内的 PowerShell 脚本与子项目、助手上层目录的带 BOM 副本一致，网站脚本仅移去 BOM。Mac 第三个 App 内的 Shell 脚本与三处发布副本逐字节一致。构建和发布文件检查通过。

## 原生验收

- Apple 芯片 Mac 助手 1.1.15 在实际系统编译、打包并打开链接，明确生图链接通过已有管道交接给生图工具。 [Mac 打包与链接实测](https://github.com/youdaowudao/subdocs/actions/runs/44238310656)
- Windows Server 2022 和 2025 本机打开 1.1.19，点击国产模型导入和确认，实际执行内置脚本，保留原默认模型和 Key。相同源码的 Windows 测试构建仅将校验接口指到本机模拟服务，逐项通过画图链接冷启动、执行期间连点和完成后再点，B 写入画图工具，Codex 凭据文件的哈希不变。 [Windows 原生验收](https://github.com/youdaowudao/subdocs/actions/runs/44238588147)
- 首轮联合候选的 Linux BusyBox 进程测试因夹具借用真实进程号未通过。将模拟进程号移出真实系统范围，生产脚本和门禁判定保持原样。 [首轮联合候选](https://github.com/youdaowudao/subdocs/actions/runs/44238798959)
- 更新夹具后，Apple 芯片 Mac 国产模型导入、Linux 完整回归和发布文件三项通过。Mac 第三个 App 的实际交付脚本完成导入，官方桌面后端的可见菜单含两款 GPT-6.2 和全部 10 个国产模型。 [联合候选门禁](https://github.com/youdaowudao/subdocs/actions/runs/44239217111)
- macOS 15.8.2 Apple 芯片运行器给合集和独立 Mac 助手逐个整体临时签名，签名验证全部通过。加浏览器隔离标记后实开，截图均显示 Apple 无法验证，未出现「已损坏」。系统设置的用户首次放行在运行器上未完成。正式包使用此轮签名产物。 [Mac 签名和首次打开](https://github.com/youdaowudao/subdocs/actions/runs/44238799083)
- 真实中转鉴权、生图上游、GPT-6.2 生成调用、计费，以及网站两个入口的联调需分别验证。这些结果不从模型菜单可见或本地模拟导入推断。

## 签名成品 SHA-256

- 合集 `085c85d5e94deb2558641b48bee7f350b4adc4bb1523cf22e4481528e9726905`
- Windows 助手 `74dfcbce902c1997bb0b0742b458e82974e416a5c2614ed78cbb60cc8913256e`
- Mac 助手 `5370e83d6b45330c843ab6e707463763e2935f631f774bc6e76554536fc47dd2`
