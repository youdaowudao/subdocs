# Codex CLI 内部命令

本页讲的是已经进入 Codex 交互界面之后，在输入框里输入的 `/...` 命令。  
如果你还没有安装 Codex 或还没有配置 UseGoodAI，先看 [Codex](/clients/codex)；如果你要在系统终端里运行 `codex exec`、`codex fork`、`codex mcp` 这类外部命令，看 [Codex 进阶用法](/external/codex-advanced)。

以下内容基于当前本机可验证的 `codex-cli 0.142.4` 写作。Codex CLI 的内部命令会随版本、功能开关、插件、MCP 和当前环境变化；实际可用项以你在 Codex 输入框里输入 `/` 后弹出的菜单为准。

## 先分清三种入口

很多使用问题都来自把“外部命令”和“内部命令”混在一起。

| 入口 | 在哪里输入 | 典型示例 | 适合做什么 |
| --- | --- | --- | --- |
| 外部 CLI 命令 | 系统终端、PowerShell、WSL、macOS Terminal | `codex fork --last` | 启动、恢复、分叉、非交互执行、管理配置 |
| CLI 内部命令 | 已经进入 Codex 后的输入框 | `/goal 修复登录页错误提示` | 控制当前会话、切换模型、审查、查看状态 |
| Codex App 命令 | Codex App 的 thread composer | `/...` | 在桌面 App 的线程里控制任务 |

如果你已经在 Codex CLI 里面，就优先用 `/goal`、`/fork`、`/review`、`/model` 这类内部命令；不要每次都退出到外部终端再敲 `codex ...`。

## 怎么打开命令菜单

进入项目目录后启动 Codex：

```bash
codex
```

在 Codex 输入框里直接输入：

```text
/
```

这会打开内部命令菜单。你可以继续输入关键词过滤，例如：

```text
/goal
/fork
/review
/model
```

看到想用的命令后，按回车确认；不想执行就按 `Esc` 取消。

## 最常用的内部命令

| 命令 | 用途 | 什么时候用 |
| --- | --- | --- |
| `/goal` | 设置或查看长期任务目标 | 多轮任务、需要持续推进时 |
| `/review` | 审查当前改动并找问题 | 改完代码、提交前、自查时 |
| `/fork` | 从当前会话分叉一条新方向 | 想保留上下文，但换一种处理思路 |
| `/resume` | 恢复一个保存过的聊天 | 继续之前的会话 |
| `/model` | 切换模型和 reasoning effort | 当前任务需要更快或更强的模型时 |
| `/permissions` | 调整 Codex 允许执行的操作 | 只读分析、常规开发、需要扩大权限时 |
| `/status` | 查看当前会话配置和 token 使用 | 不确定当前模型、目录、权限或消耗时 |
| `/diff` | 查看当前 git diff，包括未跟踪文件 | 让 Codex 总结或检查改动前 |
| `/compact` | 压缩当前会话上下文 | 长会话接近上下文限制时 |
| `/plan` | 切换到 Plan mode | 先讨论方案，不想马上改文件时 |
| `/copy` | 复制最近一次回复为 Markdown | 想把 Codex 回复贴到文档、Issue 或 PR 时 |

内部命令不是普通聊天内容。比如你输入 `/goal`，Codex 会把它当作控制命令；如果你想让 Codex 在文档里写出 `/goal` 这几个字，可以明确说“请把 `/goal` 作为文本写进文档”。

## 当前本机菜单速查

下面只列当前 `codex-cli 0.142.4` 在本机 `/` 菜单里可见的内部命令，目的是帮你快速认识常见入口；它不是 Codex 所有版本、所有环境的完整命令清单。不同版本、插件、App、IDE 联动和功能开关都可能增减项目；如果你的菜单不一样，以你本机为准。

| 命令 | 菜单含义 | 使用建议 |
| --- | --- | --- |
| `/model` | 选择模型和 reasoning effort | 任务变复杂、变简单或成本敏感时切换 |
| `/fast` | 1.5 倍速度模式，会增加用量 | 轻量问答或小改动时使用 |
| `/ide` | 带入 IDE 当前选择、打开文件等上下文 | 在 IDE 联动环境里让 Codex 看当前编辑位置 |
| `/permissions` | 选择 Codex 被允许执行什么 | 改文件、跑命令、只读分析前先确认权限 |
| `/keymap` | 重新映射 TUI 快捷键 | 需要改键位时使用 |
| `/vim` | 开关输入框 Vim 模式 | 习惯 Vim 输入时使用 |
| `/experimental` | 开关实验功能 | 只在明确知道影响时使用 |
| `/approve` | 批准最近一次 auto-review denial 的一次重试 | 遇到自动审查拦截且确认可以重试时使用 |
| `/memories` | 配置 memory 使用和生成 | 需要跨会话保留稳定偏好时使用 |
| `/skills` | 使用 skills 改善特定任务表现 | 任务需要专门工作流时使用 |
| `/import` | 从 Claude Code 导入 setup、项目和最近聊天 | 迁移工具或复用旧上下文时使用 |
| `/hooks` | 查看和管理 lifecycle hooks | 排查或控制工具调用、命令、文件编辑流程 |
| `/review` | 审查当前改动并找问题 | 提交前、改完后、自查时使用 |
| `/archive` | 归档当前会话并退出 | 想收起会话但保留记录时使用 |
| `/delete` | 永久删除当前会话并退出 | 确认不要这条会话时才使用 |
| `/resume` | 恢复保存过的聊天 | 继续历史会话时使用 |
| `/fork` | 分叉当前聊天 | 保留上下文但换方向时使用 |
| `/init` | 创建带 Codex 指令的 `AGENTS.md` | 给项目沉淀长期规则时使用 |
| `/compact` | 总结会话，避免触及上下文上限 | 长会话继续推进前使用 |
| `/plan` | 切换到 Plan mode | 先讨论方案，不希望立即改文件时使用 |
| `/goal` | 设置或查看长任务目标 | 多轮任务、需要明确完成标准时使用 |
| `/copy` | 复制最近一次回复为 Markdown | 搬运到文档、Issue、PR 时使用 |
| `/raw` | 切换 raw scrollback 模式 | 需要更好地从终端复制文本时使用 |
| `/diff` | 显示 git diff，包括未跟踪文件 | 总结改动、审查改动前使用 |
| `/mention` | 引用文件 | 明确让 Codex 读取具体文件时使用 |
| `/status` | 显示当前会话配置和 token 使用 | 排查模型、目录、权限、消耗时使用 |
| `/title` | 配置终端标题显示项 | 同时开多个 Codex 窗口时使用 |
| `/statusline` | 配置状态栏显示项 | 想调整底部状态信息时使用 |
| `/theme` | 选择语法高亮主题 | 改善可读性时使用 |

官方功能页可能提到某些在你当前菜单里暂时看不到的命令，例如只在特定版本、实验功能、App 或 IDE 环境里出现的命令。不要把这张表当成“未列出就不存在”；先在自己的 Codex 输入框里输入 `/` 核对。

## `/goal`：给长任务设定完成标准

`/goal` 适合多轮任务。它的重点不是“启动一个新工具”，而是让 Codex 在后续工作里一直记住目标、范围和完成标准。

常用写法：

```text
/goal 重写 Codex 内部命令文档，要求区分 CLI 内部命令、外部 codex 命令和 Codex App 命令，写完后运行构建验证。
```

查看当前目标：

```text
/goal
```

暂停目标：

```text
/goal pause
```

恢复目标：

```text
/goal resume
```

清除目标：

```text
/goal clear
```

推荐把目标写得具体一点：

```text
/goal 修复登录页提交后不显示错误提示的问题。范围只包括 src/pages/login 和相关测试。完成标准是相关测试通过，并说明改动和未验证项。
```

不推荐这样写：

```text
/goal 优化项目
```

“优化项目”太宽泛，Codex 很难判断什么时候算完成。更好的方式是写清楚任务对象、允许范围和验收方式。

## `/review`：在当前会话里做审查

`/review` 用来让 Codex 审查当前改动。它通常比直接说“帮我看看”更明确，因为 Codex 会进入审查导向，优先找 bug、风险、回归和缺少验证的地方。

常用写法：

```text
/review
```

也可以加上审查范围：

```text
/review 只审查 docs/external 下面的文档改动，重点看是否有命令入口混淆、事实不确定却写成确定、链接失效。
```

适合使用 `/review` 的场景：

| 场景 | 建议 |
| --- | --- |
| 文档改完 | 让 Codex 检查链接、结构、重复内容和误导性表述 |
| 代码改完 | 让 Codex 优先找 bug、边界条件和缺少测试 |
| 准备提交 | 让 Codex 检查 diff 是否包含无关改动 |
| 不确定方案 | 先让 Codex 做风险审查，不急着继续实现 |

`/review` 不是测试替代品。审查结束后，仍然要运行项目自己的构建、测试或预览命令。

## `/fork` 和 `/resume`：会话分叉与恢复

`/fork` 适合在当前上下文基础上开一条新方向。比如当前会话已经读完登录模块，你可以分叉出不同任务：

```text
/fork 基于当前分析，只修复登录错误提示，不做其他重构。
```

```text
/fork 基于当前分析，只写测试计划，不修改代码。
```

`/resume` 适合恢复历史聊天：

```text
/resume
```

外部命令里也有 `codex fork` 和 `codex resume`。区别是：

| 你在哪里 | 应该用什么 |
| --- | --- |
| 已经在 Codex 输入框里 | `/fork`、`/resume` |
| 还在系统终端里，没有进入 Codex | `codex fork`、`codex resume` |

已经在内部会话里时，用 `/fork` 通常更自然；外部 `codex fork --last` 更适合从终端直接启动一个分叉会话。

## `/model`、`/fast` 和 `/permissions`

`/model` 用来切换模型和 reasoning effort：

```text
/model
```

适合在这些时候使用：

| 场景 | 建议 |
| --- | --- |
| 小改动、简单问答 | 选择更快、更省的模型或较低 reasoning |
| 复杂重构、疑难 bug | 选择更强模型或更高 reasoning |
| 当前回答质量不稳定 | 先检查当前模型，再决定是否切换 |

`/fast` 用来切换更快的响应模式。它适合轻量任务，但可能增加用量或降低深度，复杂方案和高风险改动不建议只追求快。

`/permissions` 用来选择 Codex 允许做什么：

```text
/permissions
```

如果只是解释代码，尽量保持只读；如果要修改项目文件，选择能写当前工作区的模式；只有在你明确知道风险、且环境已经隔离时，才使用更宽的权限。

## `/status`、`/diff` 和 `/compact`

`/status` 用来查看当前会话状态：

```text
/status
```

它适合确认当前模型、工作目录、权限、token 使用等信息。发现 Codex 行为不符合预期时，先看 `/status`，再排查配置。

`/diff` 用来查看当前 git diff：

```text
/diff
```

它适合在让 Codex 总结改动、审查改动、写提交说明前使用。注意：如果当前目录不是正常 git 仓库，`/diff` 可能无法提供完整结果。

`/compact` 用来压缩长会话上下文：

```text
/compact
```

当一个会话已经跑了很久、上下文快满时，可以先让 Codex 总结当前状态，再执行 `/compact`。压缩后适合继续同一个任务，但不要指望它保留每一个细节。

## `/plan`：先讨论，不马上改

`/plan` 用来切换到 Plan mode：

```text
/plan
```

适合这些场景：

| 场景 | 为什么先用 Plan mode |
| --- | --- |
| 需求还不清楚 | 先澄清范围，避免 Codex 直接改错方向 |
| 涉及多文件、多模块 | 先列方案和影响面 |
| 只是想讨论 | 明确告诉 Codex 暂时不要动文件 |
| 要做风险评估 | 先收敛事实、假设、建议和结论 |

如果你已经明确要 Codex 直接实现，就不需要每次都进 Plan mode；直接描述任务和验收标准即可。

## `/init`、`/skills`、`/hooks`、`/memories` 和 `/import`

这些命令更偏长期配置和能力扩展。

| 命令 | 用途 | 使用建议 |
| --- | --- | --- |
| `/init` | 创建或更新 `AGENTS.md` | 给当前项目写长期规则、验证命令、禁止事项 |
| `/skills` | 查看或使用 skills | 让 Codex 按特定工作流处理任务 |
| `/hooks` | 查看和管理 lifecycle hooks | 需要在工具调用、命令执行、文件编辑前后做控制时 |
| `/memories` | 配置记忆使用和生成 | 让 Codex 跨会话记住稳定偏好或背景 |
| `/import` | 从 Claude Code 导入 setup、项目和最近聊天 | 迁移工具或复用旧上下文时 |

对于普通用户，最常用的是 `/init`。例如一个项目长期要求“修改代码后必须运行 `npm run build`”，就应该写进 `AGENTS.md`，而不是每次都在 prompt 里重复。

Hooks、skills、memories 都可能影响 Codex 的行为。排查“为什么 Codex 总是这样做”时，要把这些入口也检查一遍。

## `/copy`、`/raw`、`/mention` 和显示设置

这些命令主要改善交互体验。

| 命令 | 用途 |
| --- | --- |
| `/copy` | 把最近一次 Codex 回复复制成 Markdown |
| `/raw` | 切换更适合终端选择复制的 raw scrollback 模式 |
| `/mention` | 在输入里引用文件 |
| `/keymap` | 调整 TUI 快捷键 |
| `/vim` | 开关输入框 Vim 模式 |
| `/ide` | 带入 IDE 当前选择、打开文件等上下文 |
| `/title` | 配置终端标题显示项 |
| `/statusline` | 配置底部状态栏显示项 |
| `/theme` | 选择语法高亮主题 |

如果你要让 Codex 读某个具体文件，可以用 `/mention` 或直接在输入里提到文件路径。引用文件比笼统说“看一下这个项目”更稳定，也更省上下文。

## `/archive` 和 `/delete`

这两个命令会影响当前保存的会话。

| 命令 | 作用 | 风险 |
| --- | --- | --- |
| `/archive` | 归档当前会话并退出 | 之后需要从归档里找回 |
| `/delete` | 永久删除当前会话并退出 | 删除后通常无法恢复 |

不确定时不要用 `/delete`。只是想收起历史会话，用 `/archive` 更稳妥。

## Codex App 和 CLI 的区别

Codex App 也有 slash commands，但它不是“把 CLI 原样放进一个窗口”。两者的重点不同：

| 项目 | Codex CLI | Codex App |
| --- | --- | --- |
| 主要入口 | 终端 | 桌面 App |
| 工作方式 | 面向当前目录和终端工作流 | 面向多个 thread、worktree、App 内置界面 |
| 命令位置 | CLI 输入框 | App 的 thread composer |
| 可用命令 | 受 CLI 版本、功能开关、插件影响 | 受 App 版本、账号权限、当前环境影响 |
| 适合人群 | 熟悉终端、需要精确控制目录和命令的人 | 想在图形界面里并行管理多个 Codex 线程的人 |

所以文档里不要把 App 命令直接等同于 CLI 命令。看到教程写 `/goal` 时，要先确认它说的是 CLI 输入框还是 App thread composer；看到教程写 `codex fork --last` 时，要知道那是外部终端命令。

## 推荐工作流

### 先设目标，再让 Codex 动手

```text
/goal 重写 Codex 内部命令文档，要求区分内部命令、外部命令和 App 命令，写完后运行 npm run docs:build。
```

然后输入普通任务：

```text
请先阅读 docs/external/codex-advanced.md 和 docs/external/index.md，整理你准备怎么改，不要马上写。
```

确认方向后再让它实现。

### 改完后审查当前改动

```text
/diff
```

```text
/review 只审查当前文档改动，重点看是否有命令入口混淆、事实不确定却写成确定、内部命令示例是否清楚。
```

### 长会话接近上限时压缩上下文

```text
请先总结当前任务状态：已完成什么、还没做什么、关键文件和验证命令是什么。
```

```text
/compact
```

## 常见误区

| 误区 | 正确理解 |
| --- | --- |
| 进入 Codex 后还总是敲 `codex fork --last` | 在内部输入框里优先用 `/fork` |
| 把 `/goal` 当成外部命令 | `/goal` 是内部 slash command，不是 `codex goal` |
| 以为所有人都有完全相同的命令菜单 | 命令会随版本、功能开关、插件和环境变化 |
| 用 `/review` 后就不跑测试 | 审查不能替代构建和测试 |
| 不确定权限时直接放大权限 | 先用 `/permissions` 查看并按任务选择最小权限 |
| 把 Codex App 和 CLI 当成完全一样 | 两者入口、界面和可用命令都可能不同 |

遇到教程和你本机显示不一致时，优先相信当前输入框里 `/` 打开的菜单，再结合：

```bash
codex --version
codex --help
codex features list
```

如果是 UseGoodAI 接入问题，优先检查后台生成配置、`auth.json`、`config.toml` 和 [Codex 基础接入页](/clients/codex)。
