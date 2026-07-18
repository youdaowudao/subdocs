# 快速开始

本文适合第一次使用 UseGoodAI 的用户。按顺序创建 API Key、安装 CC Switch、把配置导入 Codex；完成后，Codex CLI 或 ChatGPT 桌面应用中的 Codex 就能通过 UseGoodAI 使用模型，不需要手动修改配置文件。

## 第一步：创建 API Key

### 1. 进入 API 密钥页面

注册并登录 UseGoodAI 后台，左侧进入 **API 密钥**，然后点击 **创建密钥**。

<a class="doc-image-link" href="/images/quick-start/create-api-key-1.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-1.jpg" alt="进入 API 密钥页面并点击创建密钥">
</a>

### 2. 填写名称并选择分组

名称写成能看懂用途的名字，例如 `编程专用`。

选择需要使用的分组。分组决定这个 API Key 可以使用哪些模型和对应的计费档位。

<a class="doc-image-link" href="/images/quick-start/create-api-key-2.jpg" target="_blank" rel="noopener">
  <img src="/images/quick-start/create-api-key-2.jpg" alt="填写密钥名称并选择正确分组">
</a>

除名称和分组外，其它限制项保持默认。创建完成后回到 API 密钥列表，继续安装 CC Switch。

## 第二步：安装 CC Switch

CC Switch 用来把 UseGoodAI 的地址、API Key 和模型写入 Codex。安装一次，完成导入后即可关闭。

::: tip 无法下载就进客服群
### QQ 客服群：**1020015031**

官方和国内下载入口都无法打开时，进入客服群，在 **群文件** 中下载 Windows 或 Mac 安装包。
:::

| 下载来源 | 入口 |
| --- | --- |
| 官方下载 | [GitHub Releases](https://github.com/farion1231/cc-switch/releases) |
| GitCode | [国内下载](https://gitcode.com/YujinDawnlight/cc-switch-download) |
| Gitee | [国内下载](https://gitee.com/iamzhihuix/cc-switch-mirror/releases) |

Windows 用户也可以打开 PowerShell 安装：

```powershell
winget install -e --id farion1231.CC-Switch
```

Mac 用户已经安装 Homebrew 时，打开终端执行：

```bash
brew install --cask cc-switch
```

安装完成后打开 CC Switch。

## 第三步：导入配置

回到 UseGoodAI 后台的 API 密钥列表，找到刚创建的 Key，点击右侧的 **导入到 CCS**。

浏览器询问是否打开 CC Switch 时，点击 **打开**。

<a class="doc-image-link" href="/images/ccswitch/CCSWITCH导入1.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/CCSWITCH导入1.jpg" alt="在 API 密钥页面点击导入到 CCS 并允许浏览器打开 CC Switch">
</a>

## 第四步：确认导入

确认应用类型是 `Codex`，然后点击 **导入**。

<a class="doc-image-link" href="/images/ccswitch/CCSWITCH导入2.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/CCSWITCH导入2.jpg" alt="核对 Codex 的 UseGoodAI 供应商配置并点击导入">
</a>

## 第五步：重开 Codex 测试

导入完成后，确认 `UseGoodAI` 右侧显示 **使用中**。

<a class="doc-image-link" href="/images/ccswitch/CCSWITCH导入3.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/CCSWITCH导入3.jpg" alt="确认 UseGoodAI 供应商已在 Codex 中使用">
</a>

Codex CLI 用户退出当前 Codex，重新打开终端后执行：

```bash
codex
```

ChatGPT 桌面应用用户在系统托盘中点击 **Exit**，彻底退出后再重新打开应用并切换到 Codex。仍未读取新配置时，在任务管理器中结束所有 ChatGPT 相关进程，或者重启电脑后再打开。

新建一个对话或任务，不要继续使用导入前的旧对话。发送：

```text
测试
```

能正常收到回复，就说明接入成功。需要核对实际请求时，进入 UseGoodAI 后台的 **使用记录** 页面查看。

重新打开 Codex，测试正常后即可关闭 CC Switch，以后也不用再打开。

## 常见问题

| 现象 | 检查动作 |
| --- | --- |
| 点击“导入到 CCS”没有反应 | 确认 CC Switch 已安装并打开，再允许浏览器打开外部应用 |
| 导入窗口里的应用类型不是 Codex | 点击取消，回到同一个 API Key 后重新点击 **导入到 CCS** |
| 导入后 Codex 仍使用旧配置 | 彻底退出 Codex，重新打开后新建对话或任务测试 |
| `401 Unauthorized` | 回到后台重新导入当前有效的 API Key |
| `403 Forbidden` | 确认当前 Key 所属分组支持导入的模型 |

其它错误进入 [报错与踩坑](/errors/) 检查。

## 手动配置

后台无法打开 CC Switch 时，进入 [Codex 手动接入](/clients/codex-manual-config)。
