# Mac 工具提示“已损坏”的复现与修复（2026-11-11）

记录版本 1.0.0；助手 1.1.12、生图 0.9.5（子项目 usegoodai-imagines-tool 提交 edadb05）、国产模型导入 1.0.2。

## 问题

客户在 Mac 上运行合集里的三个工具，双击提示“已损坏，无法打开”。以往 Mac 测试都直接运行、不带浏览器下载留下的隔离标记，Gatekeeper 不会检查，因此从未覆盖。

## 复现（签名前，网站合集 20261111-1418）

[Mac 实际打开测试](https://github.com/youdaowudao/subdocs/actions/runs/42966470636)，macOS 15.8.2，Apple 芯片：

- 三个 App 的 `codesign --verify` 均失败：code has no resources but signature indicates they must be present；`syspolicy_check` 标为 Codesign Error（Fatal）。App 内程序只有编译器自动加的临时签名（标识 a.out），App 整体没有签名。
- 不带隔离标记：双击后启动器运行并打开终端，弹出“控制终端”授权。
- 带 Safari 下载格式的隔离标记：三个工具都弹出 “is damaged and can’t be opened. You should move it to the Trash.”，程序没有运行；“已损坏”没有「仍要打开」入口。
- 3 号国产模型导入自 2026-11-08 起未改动也同样损坏，问题来自一贯的打包方式，非 0.9.4 引入。

## 修复

- `usegoodai-codex-installer/desktop/sign_mac.py` 在 Apple 芯片 Mac 上用系统 `codesign --force --deep --sign -` 对 zip 中每个 App 整体签名并 `--strict` 校验，原有条目顺序、时间、权限不变，只重签启动器并新增 `_CodeSignature`。
- “Mac 工具签名与打开测试”工作流在 `actions-test` 上签名合集与 Mac 助手 zip，按客户方式实际打开；签好的文件提交到网站下载目录，工作流同时核对仓库文件与重新签名结果是否逐字节一致。
- 无开发者证书与公证（用户 2026-11-02 决定），用户首次仍需在「系统设置 → 隐私与安全性」点「仍要打开」。

## 验证（签名后）

[签名与打开测试](https://github.com/youdaowudao/subdocs/actions/runs/42970537464)，macOS 15.8.2：

- 合集三个 App 与 Mac 助手 zip 的 App 签名有效（valid on disk，satisfies its Designated Requirement）；`syspolicy_check` 只剩 Notary Ticket Missing（未公证），不再有签名错误。
- 带隔离标记双击：提示变为 “Not Opened — Apple could not verify … is free of malware”，可在「隐私与安全性」中放行。
- 生图 App 内部程序带隔离标记直接运行 `version` 输出 0.9.5。
- 本机核对：签名只改变三个启动器并新增 `_CodeSignature/CodeResources`；生图 App 内程序仍等于网站 0.9.5 darwin-arm64；合集 `中转站快速导入工具_20261111-1814.zip`（SHA-256 `5cb32f5826193bac7d357d95738b9f140f802899c7bdb5b9fdefed690ac856ec`）；使用说明分别放进 Mac、Windows 目录，替换说明不改动其余已签名条目。

## 未验证

- 「仍要打开」未实测：macOS 15 已不支持 `spctl --add`；运行器没有给自动化脚本开辅助功能权限，系统设置停在页面顶部，读不到窗口元素，无法滚到“安全性”区域点击（[复测](https://github.com/youdaowudao/subdocs/actions/runs/42972695389)）；点击后还需输入管理员密码。签名后提示属于“无法验证”，按 Apple 官方说明可在「隐私与安全性」底部点「仍要打开」放行，但这一步与放行后的完整运行、控制终端授权后的安装流程均未在运行器上验证。
- 最终文件复测：[签名与打开测试](https://github.com/youdaowudao/subdocs/actions/runs/42972051134) 确认仓库中的两个 zip 与重新签名结果逐字节一致；同一提交的三项既有检查与 Windows 窗口测试通过。
- macOS 14 运行器已下线未测；macOS 26 未测。
