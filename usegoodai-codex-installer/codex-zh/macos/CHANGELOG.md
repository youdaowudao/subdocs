# Mac Codex 桌面版中文化版本记录

## 1.0.1 · 2026-11-19

- 在用户中断关闭旧窗口的过程中恢复正常启动，并关闭重开期间迟到的临时调试实例。Windows 发布文件继续使用 1.0.4。
- 回归覆盖关闭时中断和调试实例延迟出现。发布脚本 SHA-256 为 `630adf407873f7b77ca0730ce97eb24b5632a86091c18d0529caa9434b985c5e`。

## 1.0.0 · 2026-11-19

- 在同一个 `codex-zh` 项目增加 Mac 独立命令。沿用项目既有退出顺序和 Windows 版缓存逻辑，使用官方 Codex 写入简体中文偏好，收起调试实例后正常重开。
- Mac 发布脚本为无 BOM 的单文件，Windows 已发布的两个脚本副本字节不变。
- Apple 芯片 macOS 15.8.2 实测 OpenAI 签名桌面版 26.1111.71704 和内置 CLI 0.169.1。确认关闭原实例、临时调试端口退出、配置和备份完整、签名及应用文件哈希一致。登录页截图从英文切换成简体中文。Intel Mac 和登录后的工作区未验证。 [实测与截图](https://github.com/youdaowudao/subdocs/actions/runs/44526350038)
- 测试的发布脚本 SHA-256 为 `d9b9f33352f961764296554cc9299abe5292d6a7ba8c036fdcb10e1ee1b64d42`。上游参考为 `zhenglei410/codex-i18n-cache-seeder-macos` 的 `346c43e4b977aaa58f3a0b2ffbb8b54729312904`。
