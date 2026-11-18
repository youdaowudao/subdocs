# 生图恢复与 Windows 窗口改版

2026-11-18。生图 0.9.7，Windows 接入助手 1.1.21。生图源码提交 `698d3de8` 位于 `usegoodai-imagines-tool` 的本地 `main`。按用户要求保留为本地候选，正式主线未发布此版。

## 验证结果

- Linux x64、Windows x64、Apple 芯片 Mac、Intel Mac 用同一组正式版本程序测试。0.9.6 安装后移走工具目录、留下 Skill 和规则，0.9.6 复现原报错。0.9.7 用新画图 Key 恢复安装，重复导入成功，编程凭据保持原字节。四个平台的新旧生图程序与本地最终候选使用的发布文件一致。 [原生安装和升级记录](https://github.com/youdaowudao/subdocs/actions/runs/44296421172)
- 生图 Go 全量及 64 项子项目契约测试通过。同名自定义 Skill 保留，只有官方说明、只有官方代理配置或只剩空子目录的恢复用例均通过。Windows 接入助手 Go 测试通过。
- Chromium 验证两个接入页都在手工输入上方显示分组、网站导入按钮名及 API 密钥页入口。420×690 的窗口能完整显示，375×600 可以纵向滚动。底部两张卡片显示用途和状态，国产模型导航可点击。
- Apple 芯片 macOS 15.8.2 对合集内各 App 执行整体临时签名和隔离标记打开检查，签名校验通过。最终 ZIP 内第二个 App 与签名产物一致。系统首次放行和客户实机点击未验证。 [Mac 签名及打开记录](https://github.com/youdaowudao/subdocs/actions/runs/44296420943)
- 初版测试分支 Windows 检查因页面静态断言仍查找旧生图按钮文字而失败。最终版更新该断言并通过本地测试，等待允许推送后再执行最终 EXE 的 Windows 原生窗口回归和同提交的三项发布门禁。真实中转鉴权、计费和生图未验证。 [初版 Windows 检查](https://github.com/youdaowudao/subdocs/actions/runs/44296420996)

## 本地候选成品

- Windows EXE SHA-256 `e0e6a219fc88a688c82f13042c2dd56e9473f5be096570875960a933f7420654`。
- 工具合集 SHA-256 `c926f7a01a82f53a789becf4260999db4cfd34da57f3e0dc20d4232879615d3e`。
- 合集内的 Windows EXE 与独立 EXE 相同，第二个 Mac App 的版本资源与原生工具均为 0.9.7。
