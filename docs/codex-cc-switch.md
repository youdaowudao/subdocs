---
title: Codex CC Switch 接入
---

# Codex CC Switch 接入

不运行脚本时，用 CC Switch 从后台导入 Codex 配置。导入后彻底退出 Codex，再重新打开测试。

## 1. 安装 CC Switch

| 下载来源 | 入口 |
| --- | --- |
| 官方 GitHub | [GitHub Releases](https://github.com/farion1231/cc-switch/releases) |
| GitCode | [国内下载](https://gitcode.com/YujinDawnlight/cc-switch-download) |
| Gitee | [国内下载](https://gitee.com/iamzhihuix/cc-switch-mirror/releases) |

<details>
<summary>查看下载文件选择说明</summary>

<a class="doc-image-link" href="/images/ccswitch/ccswitchdownload.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitchdownload.jpg" alt="CC Switch 下载文件选择说明，macOS 选择 dmg 文件，Windows 选择 msi 文件">
</a>

</details>

<details>
<summary>或者采用命令行安装方式</summary>

Windows 打开 PowerShell 执行：

```powershell
winget install -e --id farion1231.CC-Switch
```

macOS 已安装 Homebrew 时执行：

```bash
brew install --cask cc-switch
```

</details>

安装完成后打开 CC Switch。

## 2. 从后台导入配置

回到后台 **API 密钥**，找到要使用的 Key，点击 **导入到 CCS**。

浏览器询问是否打开 CC Switch 时，点击 **打开**。确认应用类型是 `Codex`，再点击 **导入**。

<details>
<summary>查看导入截图</summary>

<a class="doc-image-link" href="/images/ccswitch/CCSWITCH导入1.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/CCSWITCH导入1.jpg" alt="在 API 密钥页面点击导入到 CCS 并允许浏览器打开 CC Switch">
</a>

<a class="doc-image-link" href="/images/ccswitch/CCSWITCH导入2.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/CCSWITCH导入2.jpg" alt="核对 Codex 的 UseGoodAI 供应商配置并点击导入">
</a>

</details>

## 3. 关闭并重新打开 Codex

导入完成后，确认 `UseGoodAI` 右侧显示 **使用中**。

<details>
<summary>查看使用中截图</summary>

<a class="doc-image-link" href="/images/ccswitch/CCSWITCH导入3.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/CCSWITCH导入3.jpg" alt="确认 UseGoodAI 地址正确并显示使用中">
</a>

</details>

彻底退出 Codex，再重新打开并新建任务，发送：

```text
测试
```

能正常回复，就接入完成。测试正常后可以关闭 CC Switch。

<details>
<summary>常见问题</summary>

| 现象 | 检查动作 |
| --- | --- |
| 点击“导入到 CCS”没有反应 | 确认 CC Switch 已安装并打开，再允许浏览器打开外部应用 |
| 导入窗口里的应用类型不是 Codex | 点击取消，回到同一个 API Key 后重新点击 **导入到 CCS** |
| 导入后 Codex 仍使用旧配置 | 彻底退出 Codex，重新打开后新建任务测试 |
| `401 Unauthorized` | 回到后台重新导入当前有效的 API Key |
| `403 Forbidden` | 确认当前 Key 所属分组支持导入的模型 |

</details>
