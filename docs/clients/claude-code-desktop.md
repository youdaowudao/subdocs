# Claude Code CLI / Claude Desktop 接入

Claude Desktop 是带图形界面的 AI 工作应用，包含 Chat、Cowork 和 Code 等入口；Claude Code CLI 是在终端里运行的代码 Agent。两者都可以使用 UseGoodAI 的 Anthropic 模型，但配置入口不同：Claude Code CLI 推荐从后台一键导入到 CC Switch，Claude Desktop 推荐在 CC Switch 里手动添加供应商。

先按使用入口选择对应章节。Claude Desktop 不能使用 UseGoodAI 后台的一键导入，但可以在 CC Switch 的 Claude Desktop 面板里手动配置；APP 内 Gateway 配置放在后面作为备用路径。

## 选择配置入口

| 使用入口 | 推荐配置入口 | 影响范围 |
| --- | --- | --- |
| Claude Code CLI | [后台一键导入到 CC Switch](#claude-code-cli-ccswitch) | 从当前终端启动的 Claude Code CLI |
| Claude Desktop APP | [优先用 CC Switch 手动配置](#claude-desktop-ccswitch) | APP 内的 Chat、Cowork 和 Code 等功能 |

APP 和 CLI 的配置互不替代。CLI 用户也可以在 [一键导入不可用时改用终端配置](#claude-code-cli-manual)；Desktop 用户优先使用 CC Switch，CC Switch 不适用时再使用 [Gateway 手动配置](#claude-desktop-gateway)。

<a id="claude-desktop-ccswitch"></a>
## 推荐：用 CC Switch 手动配置 Claude Desktop

这条路径适用于 **Claude Desktop APP**。UseGoodAI 后台的 **导入到 CCS** 目前只直接导入 Claude Code CLI，不能直接导入 Claude Desktop；Desktop 需要在 CC Switch 里选中对应面板后手动添加一次供应商。

### 1. 选择 Claude Desktop 并新建供应商

打开 CC Switch，点击顶部的 **Claude Desktop** 图标，再点击右上角橙色 `+`。

<a class="doc-image-link" href="/images/ccswitch/ccswitch1.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch1.jpg" alt="在 CC Switch 选择 Claude Desktop 并点击右上角加号">
</a>

顶部图标代表不同的目标工具。这里必须选 **Claude Desktop**，不要选 Claude Code；选错后配置不会写入 Desktop。

### 2. 选择 Claude 供应商的自定义配置

保持顶部选中 **Claude 供应商**，在预设供应商列表中点击 **自定义配置**，再点击右下角 **添加**。

<a class="doc-image-link" href="/images/ccswitch/ccswitch2.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch2.jpg" alt="在 Claude Desktop 的 Claude 供应商中选择自定义配置并点击添加">
</a>

### 3. 填写四个字段并保存

进入 **编辑供应商** 后填写：

| 字段 | 填写内容 |
| --- | --- |
| 供应商名称 | `UseGoodAI.com` |
| 官网链接 | `https://api.usegoodai.com` |
| API Key | UseGoodAI API Key |
| 请求地址 | `https://api.usegoodai.com` |

<a class="doc-image-link" href="/images/ccswitch/ccswitch3.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch3.jpg" alt="在 Claude Desktop 的 CC Switch 供应商配置中填写四个字段">
</a>

**完整 URL** 开关保持关闭。官网链接和请求地址都不要添加 `/v1`，末尾也不要添加 `/`；其它字段保持默认，不需要填写模型名。填写完成后，点击右下角 **保存**。

### 4. 启用供应商并重启 Claude Desktop

回到 Claude Desktop 的供应商列表，找到 `UseGoodAI.com`，点击右侧 **启用**。

<a class="doc-image-link" href="/images/ccswitch/ccswitch4.jpg" target="_blank" rel="noopener">
  <img src="/images/ccswitch/ccswitch4.jpg" alt="在 Claude Desktop 的 CC Switch 供应商列表启用 UseGoodAI.com">
</a>

启用后，完全退出 Claude Desktop，再重新打开并新建一个对话或任务。发送 `测试`，能正常回复后，在 Desktop 的模型选择器里选择 Claude 模型。

<a id="claude-desktop-gateway"></a>
## 备用：直接在 Claude Desktop 配置 Gateway

CC Switch 不适用时，在 Claude Desktop APP 内完成下面配置。这个入口不需要 CC Switch；填好连接信息后，还要向下填写模型列表、测试连接并应用配置。

### 1. 打开第三方推理设置

从 [Claude 官方下载页](https://claude.com/download) 安装并打开 Claude Desktop。首次打开时先不要登录或创建 Anthropic 账号。

macOS 从系统菜单栏进入，Windows 从登录页左上角的菜单进入：

1. 点击 **Help → Troubleshooting → Enable Developer Mode**。
2. 点击 **Developer → Configure third-party inference**。

### 2. 填写 UseGoodAI Gateway

在 **Connection** 中填写：

| 字段 | 填写 |
| --- | --- |
| Inference provider | `Gateway` |
| Gateway base URL | `https://api.usegoodai.com` |
| Credential kind | `Static API key` |
| Gateway API key | UseGoodAI API Key |
| Gateway auth scheme | `Bearer` |

Gateway base URL 不要添加 `/v1`。填完后继续配置下面的模型列表，再运行连接测试。

### 3. 向下滚动，填写模型列表

在配置窗口向下找到 **Models**（模型）区域；带左侧导航的界面直接点击 **Models**。关闭 **Model discovery**，在 **Model list** 中手动添加模型。

先添加一个当前 Key 所属分组支持的 Claude 模型。下面以 `claude-sonnet-4-6` 为例：

| 字段 | 填写 |
| --- | --- |
| Model ID | `claude-sonnet-4-6`；换模型时填写当前 Key 所属分组可用的完整模型 ID |
| Display name | `Claude Sonnet 4.6`，只用于界面显示；留空会自动显示名称 |
| Tier alias | `sonnet` |
| Default for tier | 开启，将该模型作为 `sonnet` 的默认模型 |
| Offer 1M-context variant | 先保持关闭 |

**Model ID 必须与 UseGoodAI 接受的模型 ID 完全一致**，不能只填 `sonnet` 或显示名称 `Claude Sonnet 4.6`。模型 ID 见 [模型价格](/models)。填写 Display name 不会替代 Model ID。

需要加入其它模型时，每个模型单独添加一条，Tier alias 按模型系列选择：Sonnet 选 `sonnet`，Opus 选 `opus`，Haiku 选 `haiku`。同一系列只把一个模型设为 **Default for tier**；整个列表的第一条是默认模型，把最常用的模型放在第一条。

### 4. 测试连接并应用配置

回到 **Connection → Gateway credentials**，点击 **Test connection**。看到绿色的连接测试成功提示后，再应用配置。测试提示模型不存在或不可用时，返回 **Models**，检查 Model ID 的拼写及当前 Key 所属分组是否支持该模型，修正后重新测试。

点击 **Apply Changes**（旧版按钮名为 **Apply locally**），按提示重新启动 Claude Desktop，在登录页选择使用第三方配置进入。

重新打开后，新建一个对话或任务，在模型选择器中选中刚才配置的模型，再发送：

```text
测试
```

能正常回复后，使用 APP 内的模型选择器切换已添加的模型。

## 配置 Claude Code CLI

<a id="claude-code-cli-ccswitch"></a>
### 推荐：从后台一键导入到 CC Switch

这条路径只配置 **Claude Code CLI**，不能把 UseGoodAI 后台的导入链接直接用于 Claude Desktop。

1. 打开 UseGoodAI 管理后台的 **API 密钥**，找到要使用的 Key，点击 **导入到 CCS**。
2. 浏览器询问是否打开 CC Switch 时，点击 **打开**。
3. 确认应用类型是 **Claude Code**，点击 **导入**。
4. 导入完成后，确认 CC Switch 中的 `UseGoodAI` 显示为 **使用中**。
5. 彻底退出 Claude Code，重新打开并新建一个对话或任务。

需要看 CC Switch 内的导入确认和失败处理，直接进入 [CC Switch 的 Claude Code 一键导入](./cc-switch#ccswitch-claude-code-import)。

<a id="claude-code-cli-manual"></a>
### 备用：在当前终端设置环境变量

一键导入没有反应、CC Switch 未安装，或你不使用 CC Switch 时，在 macOS、Linux 或 WSL 终端执行：

```bash
export ANTHROPIC_BASE_URL="https://api.usegoodai.com"
export ANTHROPIC_AUTH_TOKEN="你的 UseGoodAI API Key"
claude
```

这两个环境变量只对当前终端生效。关闭终端后，下次使用前重新执行。

### 测试并切换模型

进入 Claude Code CLI 后发送：

```text
测试
```

能正常回复后，在当前对话输入 `/model`，直接切换模型，不需要新开对话。

## Claude 模型怎么切换

Claude Desktop 和 Claude Code CLI 里直接选择 Claude 模型。通过 Gateway 手动配置的 Desktop 从已添加的模型列表中选择。UseGoodAI 会按当前 API Key 所属分组调用对应的 Anthropic 模型。

不要在 APP 或 CLI 里填写 GPT 模型名，也不需要设置 `ANTHROPIC_MODEL` 或 `ANTHROPIC_DEFAULT_*_MODEL`。可用模型以 Claude 的模型选择器和后台当前 Key 所属分组为准，价格看 [模型价格](/models)。

需要通过 CC Switch 管理 Claude Code CLI 时，回到 [CC Switch 的 Claude Code 一键导入](./cc-switch#ccswitch-claude-code-import)；需要配置 Desktop 时，回到 [Desktop 的 CC Switch 主路径](#claude-desktop-ccswitch)。

## 排查

| 现象 | 处理 |
| --- | --- |
| APP 找不到第三方推理入口 | 回到登录页，按 **Help → Troubleshooting → Enable Developer Mode** 开启后再进入 **Developer** 菜单 |
| APP 应用配置后仍显示普通登录页 | 彻底退出并重新打开 APP，再选择第三方配置入口 |
| APP 的 Gateway 测试提示模型不存在或不可用 | 回到 **Models → Model list**，核对 Model ID 的完整拼写，换成当前 Key 所属分组支持的 Claude 模型，再点 **Test connection** |
| APP 的 Gateway 模型选择器为空 | 在 **Models → Model list** 中添加完整模型 ID，应用配置并重新打开 APP |
| CLI 仍在使用原来的服务 | 确认在执行 `export` 的同一个终端里启动了 `claude` |
| `401 Unauthorized` | 重新复制 UseGoodAI API Key，确认 APP 使用 `Bearer`，CLI 使用 `ANTHROPIC_AUTH_TOKEN` |
| 请求地址错误 | APP 和 CLI 都只填 `https://api.usegoodai.com`，不要添加 `/v1` |
| 切换模型后没有变化 | APP 检查模型选择器，CLI 重新输入 `/model`，确认当前 Key 分组支持所选模型 |

## 切回默认服务

Claude Desktop 回到登录页，选择 Anthropic 登录入口。

Claude Code CLI 关闭当前终端，或执行：

```bash
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN
```
