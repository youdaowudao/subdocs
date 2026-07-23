# CC Switch 手动接入

本文用于在 CC Switch 中手动添加 UseGoodAI，供 Claude Code 使用。Codex 用户看 [Codex CC Switch 接入](/codex-cc-switch)。

还没有安装 CC Switch 时，先进入 [Codex CC Switch 接入](/codex-cc-switch) 查看下载入口，安装完成后再返回本页。

## 把 UseGoodAI 添加到 Claude Code

### 1. 选择 Claude Code 并新建供应商

打开 CC Switch，点击顶部的 **Claude Code** 图标。中间列表出现 `Claude Official` 和 `default`，说明当前管理的是 Claude Code 配置。

点击右上角橙色 `+`，进入新增供应商页面。

<a class="doc-image-link" href="/images/ccswitch/ccswitch1.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch1.jpg" alt="在 CC Switch 选择 Claude Code 并点击右上角加号">
</a>

顶部图标代表不同的目标工具。选错图标会把配置写到其它工具，Claude Code 不会读取。

### 2. 选择 Claude 供应商的自定义配置

保持顶部选中 **Claude 供应商**，在预设供应商列表中点击 **自定义配置**，再点击右下角 **添加**。

<a class="doc-image-link" href="/images/ccswitch/ccswitch2.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch2.jpg" alt="在 Claude 供应商中选择自定义配置并点击添加">
</a>

本文不使用其它站点的预设，也不选择 **统一供应商**。UseGoodAI 的 Claude Code 配置只需要在这个自定义配置里填写一次。

### 3. 填写四个字段并保存

进入 **编辑供应商** 后，只填写下面四项：

| 字段 | 填写内容 |
| --- | --- |
| 供应商名称 | `UseGoodAI.com` |
| 官网链接 | `https://api.usegoodai.com` |
| API Key | UseGoodAI API Key |
| 请求地址 | `https://api.usegoodai.com` |

<a class="doc-image-link" href="/images/ccswitch/ccswitch3.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch3.jpg" alt="填写 UseGoodAI 供应商名称、官网链接、API Key 和请求地址">
</a>

**完整 URL** 开关保持关闭。官网链接和请求地址都不要添加 `/v1`，末尾也不要添加 `/`；其它字段保持默认，不需要填写模型名。

填写完成后，点击右下角 **保存**。

### 4. 启用 UseGoodAI

回到 Claude Code 的供应商列表，找到刚保存的 `UseGoodAI.com`，点击右侧 **启用**。

<a class="doc-image-link" href="/images/ccswitch/ccswitch4.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch4.jpg" alt="在 CC Switch 供应商列表启用 UseGoodAI.com">
</a>

启用后，这一行会变成当前使用中的供应商。退出当前 Claude Code，再重新打开并新建一个对话或任务。

## 在 Claude Code 中测试

在新对话中发送：

```text
测试
```

需要切换模型时，在当前会话输入 `/model`。模型在 Claude Code 内选择，不在 CC Switch 的供应商页面填写；Claude 模型与 UseGoodAI 实际模型的对应关系见 [Claude Code / Desktop 接入](/clients/claude-code-desktop#claude-模型如何映射到-gpt-5-6)。

测试成功后可以关闭 CC Switch，不需要后台运行。不要开启 **Proxy**、本地代理或本地路由功能。

## 排查

| 现象 | 检查动作 |
| --- | --- |
| 保存后 Claude Code 没有使用新配置 | 回到 CC Switch 顶部确认选中的是 Claude Code，再确认 `UseGoodAI.com` 已显示为当前使用中的供应商 |
| `401 Unauthorized` | 重新复制 UseGoodAI API Key，替换 **API Key** 字段后保存并再次启用 |
| 请求地址错误 | **官网链接** 和 **请求地址** 都改成 `https://api.usegoodai.com`，删除 `/v1` 和末尾 `/` |
| 模型无法切换 | 回到 Claude Code 输入 `/model`，不要在 CC Switch 供应商页面寻找模型字段 |
| `403 Forbidden` | 确认当前 API Key 所属分组支持所选模型；仍失败时看 [报错与踩坑](/errors/) |
