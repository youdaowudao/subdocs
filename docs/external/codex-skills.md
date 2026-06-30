# Codex Skills 使用与创建

本页面向已经在使用 UseGoodAI / Codex 的用户，说明 Codex Skills 是什么、什么时候该用、怎么创建，以及如何把重复工作流沉淀成可复用能力。

以下内容主要依据 Codex 自带的 `skill-creator` Skill 写作。不同 Codex 版本、插件版本和产品界面可能会调整 Skill 的发现、展示和验证方式；遇到差异时，以你本机 Codex、`$CODEX_HOME` 目录和官方文档为准。

## Skill 是什么

Skill 是一个自包含的文件夹，用来给 Codex 增加某一类任务的专门知识、流程和资源。它不是“更长的 prompt”，而更像一份给 Codex 使用的任务说明包：Codex 在遇到匹配任务时读取 Skill，然后按里面的工作流、参考资料、脚本和模板执行。

一个 Skill 适合解决这些问题：

| 问题 | Skill 怎么帮忙 |
| --- | --- |
| 重复工作流 | 把固定步骤写进 `SKILL.md`，减少每次重新解释 |
| 长资料反复投喂 | 把 API 文档、业务规则、数据库 schema 放进 `references/` |
| 稳定脚本重复改写 | 把可靠脚本放进 `scripts/`，需要时直接运行或轻微调整 |
| 输出模板固定 | 把报告模板、项目骨架、示例文件放进 `assets/` |
| 某类任务容易遗漏检查点 | 在 Skill 中写清验证、边界和失败处理 |

不适合做成 Skill 的内容：

| 内容 | 更合适的位置 |
| --- | --- |
| 单次任务目标 | 当前对话 prompt |
| 当前项目的长期规则 | 仓库里的 `AGENTS.md` |
| 需要连接外部系统的工具能力 | MCP 或插件 |
| 一次性修复、临时背景、未验证想法 | 当前对话或任务文档 |
| 大而全的平台化规则 | 拆成几个小 Skill，或先不要做 |

## Skill、prompt、AGENTS.md、插件和 MCP 的区别

这几个概念经常混在一起，先分清边界。

| 机制 | 主要作用 | 生命周期 | 适合放什么 |
| --- | --- | --- | --- |
| prompt | 给当前这次任务下指令 | 单次对话或单次命令 | 目标、范围、验收标准、临时约束 |
| `AGENTS.md` | 给当前仓库下长期规则 | 跟项目走 | 代码风格、验证命令、禁止事项、项目约定 |
| Skill | 给某类任务下可复用工作流 | 用户级或插件级复用 | 专门流程、资料索引、脚本、模板 |
| 插件 | 打包一组 Codex 能力 | 安装后生效 | Skills、MCP 配置、hooks、本地工具等组合能力 |
| MCP | 连接外部工具或数据源 | 运行时工具通道 | GitHub、Linear、数据库、内部文档、浏览器等工具入口 |

判断方式很简单：

| 你想解决的问题 | 优先选择 |
| --- | --- |
| “这次任务要这样做” | prompt |
| “这个仓库永远要这样做” | `AGENTS.md` |
| “以后遇到这类任务都按这套流程做” | Skill |
| “我要分发一整套能力给别人安装” | 插件 |
| “Codex 需要调用外部系统” | MCP |

Skill 可以引用 MCP，也可以通过插件分发，但它本身的核心仍然是“让 Codex 在某类任务上知道该怎么做”。

## 一个 Skill 的标准结构

一个 Skill 至少需要 `SKILL.md`。其他目录按需添加，不要为了显得完整而创建空壳。

```text
skill-name/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── scripts/
├── references/
└── assets/
```

| 路径 | 是否必须 | 用途 |
| --- | --- | --- |
| `SKILL.md` | 必须 | Skill 的元数据和核心使用说明 |
| `agents/openai.yaml` | 推荐 | UI 展示信息，例如名称、短描述、默认 prompt |
| `scripts/` | 可选 | 可执行脚本，适合确定性强、重复改写成本高的操作 |
| `references/` | 可选 | 需要按需读取的长文档、规范、schema、API 说明 |
| `assets/` | 可选 | 输出中会用到的模板、图片、字体、项目骨架、示例文件 |

Skill 文件夹名称建议使用小写字母、数字和连字符，例如 `docs-writer`、`api-debugging`、`gh-address-comments`。名称要短，最好能说明动作或任务场景。

## SKILL.md frontmatter

`SKILL.md` 顶部必须有 YAML frontmatter。普通自定义 Skill 默认只需要 `name` 和 `description`；除非当前 Codex 版本或官方说明明确支持某个字段，不要随意增加额外字段。

```markdown
---
name: docs-writer
description: Create, revise, and verify project documentation. Use when Codex needs to write user-facing docs, API docs, changelog entries, tutorials, migration guides, or documentation updates that must match an existing repo style.
---

# Docs Writer

...
```

这里最重要的是 `description`。它是 Skill 的主要触发依据：Codex 会根据所有 Skill 的 `name` 和 `description` 判断当前任务要不要加载这个 Skill。正文只有在 Skill 被触发后才会进入上下文，所以“什么时候使用这个 Skill”必须写进 `description`，不要只写在正文里的“适用场景”小节。

好的 `description` 要同时说明两件事：

| 要素 | 写法 |
| --- | --- |
| Skill 做什么 | “Create, revise, and verify project documentation” |
| 什么时候用 | “Use when Codex needs to write user-facing docs, API docs...” |

不推荐：

```yaml
description: Helps with docs.
```

这个描述太泛，触发边界不清。Codex 很难知道它应该在 README、API 文档、注释、产品文案还是任意写作任务里使用。

推荐：

```yaml
description: Create, revise, and verify repository documentation. Use when Codex needs to write or update Markdown docs, API guides, setup instructions, migration notes, or user-facing tutorials while matching the existing documentation style.
```

## 创建 Skill 的流程

创建 Skill 前，先确认它确实值得沉淀。一个可用判断是：这套流程是否已经或即将被重复使用？如果只是一次项目规则，优先写进当前 prompt 或项目 `AGENTS.md`。

### 1. 用具体例子定义 Skill

不要从抽象能力开始，例如“创建一个提升效率的 Skill”。应该先写出真实触发语句：

```text
使用 docs-writer skill 重写安装文档，保持当前文档风格。
使用 api-debugging skill 排查这个 401 问题，先确认请求、认证和服务端日志。
使用 code-review-style skill 审查当前 diff，按严重程度列出问题。
```

然后问自己：

| 问题 | 目的 |
| --- | --- |
| 用户会怎样请求这个 Skill？ | 帮助写准 `description` |
| Codex 每次都会重复哪些步骤？ | 写进 `SKILL.md` |
| 哪些资料太长，不适合每次放进正文？ | 放进 `references/` |
| 哪些操作需要确定性？ | 放进 `scripts/` |
| 哪些输出需要固定格式或模板？ | 放进 `assets/` |

### 2. 规划可复用资源

Skill 不应该只是一篇长说明。它的价值在于把不同类型的信息放到合适位置。

| 资源 | 适合内容 | 不适合内容 |
| --- | --- | --- |
| `SKILL.md` | 核心流程、选择规则、必须遵守的约束 | 大段 API 文档、完整业务资料、长示例 |
| `references/` | schema、接口文档、公司政策、详细案例 | Skill 必须立刻知道的触发信息 |
| `scripts/` | 可重复运行的检查、转换、生成、验证脚本 | 一次性命令、未经测试的草稿 |
| `assets/` | 模板、样例工程、图片、字体、报告文件 | 需要 Codex 阅读理解的长说明 |

例如：

| Skill | 可以沉淀的资源 |
| --- | --- |
| `pdf-editor` | `scripts/rotate_pdf.py`、`scripts/extract_pages.py` |
| `bigquery-analyst` | `references/schema.md`、`references/metrics.md` |
| `frontend-webapp-builder` | `assets/react-template/` |
| `brand-docs` | `assets/logo.png`、`references/tone.md` |

### 3. 初始化目录

创建新 Skill 时，优先使用本机 `skill-creator` 提供的初始化脚本，而不是手写一堆文件。默认位置通常是 `$CODEX_HOME/skills`；如果没有设置 `CODEX_HOME`，一般回退到 `~/.codex/skills`。

下面的命令里的 `<skill-creator-dir>` 指 `skill-creator` 这个 Skill 在你本机的目录。不同系统和不同 `CODEX_HOME` 下路径会不同，先在本机 Codex 技能目录里找到它，再替换这个占位符。

```bash
python <skill-creator-dir>/scripts/init_skill.py my-skill --path "${CODEX_HOME:-$HOME/.codex}/skills"
```

按需创建资源目录：

```bash
python <skill-creator-dir>/scripts/init_skill.py docs-writer --path "${CODEX_HOME:-$HOME/.codex}/skills" --resources references,assets
python <skill-creator-dir>/scripts/init_skill.py api-debugging --path "${CODEX_HOME:-$HOME/.codex}/skills" --resources scripts,references
```

初始化脚本会生成基础 `SKILL.md`，并可生成 `agents/openai.yaml`。如果使用了示例文件，后续必须删除或替换占位内容；不要把无用示例留在最终 Skill 中。

### 4. 编写 SKILL.md 正文

正文只写 Skill 触发后真正需要的内容。建议包含：

| 小节 | 写什么 |
| --- | --- |
| 核心流程 | Codex 应该按什么顺序做事 |
| 输入判断 | 看到哪些情况要先澄清，哪些可以直接执行 |
| 资源使用 | 什么时候读哪个 `references/` 文件，什么时候运行哪个脚本 |
| 验证方式 | 如何确认输出正确，哪些命令必须跑 |
| 输出格式 | 用户期望的报告、diff、文档或总结形态 |
| 风险边界 | 生产系统、写操作、隐私数据、破坏性命令等限制 |

不要把 `SKILL.md` 写成百科。Skill 设计有一个重要原则：渐进披露。Codex 总是先看到 `name` 和 `description`，触发后才读 `SKILL.md`，必要时再读 `references/` 或使用 `scripts/`、`assets/`。所以正文应该是导航和工作流，不应该塞满所有资料。

### 5. 配置 agents/openai.yaml

`agents/openai.yaml` 是面向产品界面的元数据，不是给 Codex 阅读的主要说明。常见字段包括：

```yaml
interface:
  display_name: "Docs Writer"
  short_description: "编写、修订并验证项目文档内容"
  default_prompt: "Use $docs-writer to update the setup guide while matching the current documentation style."
policy:
  allow_implicit_invocation: true
```

其中 `default_prompt` 应该是短句，并显式提到 `$skill-name`。如果没有明确提供图标、品牌色等信息，不要随意编造。更新 `SKILL.md` 后，也要检查 `agents/openai.yaml` 是否过时。

如果本机有生成脚本，可以用下面的形式重新生成：

```bash
python <skill-creator-dir>/scripts/generate_openai_yaml.py <path/to/skill-folder> --interface 'display_name=Docs Writer' --interface 'short_description=编写、修订并验证项目文档内容' --interface 'default_prompt=Use $docs-writer to update the setup guide while matching the current documentation style.'
```

### 6. 验证 Skill

写完后运行快速验证：

```bash
python <skill-creator-dir>/scripts/quick_validate.py <path/to/skill-folder>
```

这个验证会检查 frontmatter 格式、必填字段和命名规则。它不能证明 Skill 的工作流一定好用，只能先挡住基础结构错误。

如果 Skill 包含脚本，还要实际运行代表性脚本，确认输入输出符合预期。不要把“看起来能跑”的脚本放进 Skill 后直接结束。

### 7. 迭代和 forward-test

复杂 Skill 写完后，建议用新的子代理或新会话做 forward-test。做法不是让另一个代理“审查这个 Skill”，而是像真实用户一样给任务：

```text
Use $api-debugging at /path/to/api-debugging to diagnose this failed request.
```

forward-test 的目的，是观察一个没有你脑内背景的 Codex 是否能正确触发、读取资源、执行流程并产出可用结果。测试时应该传原始任务材料，不要提前告诉它你认为哪里有问题，也不要泄露预期答案。

## 妙用 Skill 的方法

### 把重复工作流沉淀成步骤

如果你每次都在 prompt 里写：

```text
先读现有文档风格，再列结构，再写正文，最后检查链接和不确定表述。
```

这就适合做成文档写作 Skill。`SKILL.md` 可以只保留稳定步骤：

```markdown
## Workflow

1. Read nearby documentation before editing.
2. Identify audience, scope, and required verification.
3. Draft the smallest complete document that satisfies the task.
4. Check links, commands, version-sensitive claims, and stale comments before completion.
```

这样每次任务 prompt 只需要说明目标文件和具体主题。

### 把长资料放进 references

长资料不要塞进 `SKILL.md`。例如 API 调试 Skill 可以这样组织：

```text
api-debugging/
├── SKILL.md
└── references/
    ├── auth-errors.md
    ├── rate-limits.md
    └── provider-response-shapes.md
```

然后在 `SKILL.md` 里写清楚什么时候读：

```markdown
For 401 or 403 errors, read `references/auth-errors.md` before proposing fixes.
For 429 errors or quota issues, read `references/rate-limits.md`.
```

这比把所有错误码资料堆在正文里更省上下文，也更容易维护。

### 把稳定脚本放进 scripts

脚本适合做确定性强、容易重复写错的事，例如：

| 任务 | 脚本示例 |
| --- | --- |
| 检查 frontmatter | `scripts/check_frontmatter.py` |
| 生成 API 报告 | `scripts/render_report.py` |
| 清理导出数据 | `scripts/normalize_export.py` |
| 批量转换文档 | `scripts/convert_docs.py` |

脚本不是越多越好。只有当同类代码会被反复改写，或者错误成本明显高于维护脚本成本时，才放进 `scripts/`。

### 用 assets 放模板

`assets/` 适合放会被复制、改写或作为输出基础的文件。比如：

```text
docs-writer/
└── assets/
    ├── tutorial-template.md
    ├── api-reference-template.md
    └── migration-guide-template.md
```

注意：`assets/` 不是给 Codex 长篇阅读的地方。如果模板里包含复杂规则，应把规则拆到 `references/` 或 `SKILL.md` 中说明。

### 用子代理 forward-test skill

当 Skill 影响范围比较大时，forward-test 比自我感觉更可靠。可以准备两到三个真实任务：

| 测试任务 | 观察点 |
| --- | --- |
| 简单成功路径 | 是否能按流程完成，不额外发散 |
| 缺少关键信息 | 是否会先问问题，而不是编造 |
| 有生产风险 | 是否会停下来要求确认或只做只读分析 |

如果测试失败，优先修改触发描述、流程顺序或资源导航，而不是把正文越写越长。

## 高级经验

### 渐进披露比长文更重要

Skill 的加载大致可以理解为三层：

| 层级 | 什么时候进入上下文 | 应该放什么 |
| --- | --- | --- |
| metadata | 总是在 Skill 列表中可见 | `name` 和 `description` |
| `SKILL.md` 正文 | Skill 触发后 | 核心流程和资源导航 |
| bundled resources | Codex 判断需要时 | 长资料、脚本、模板、素材 |

`SKILL.md` 接近 500 行时就应该警惕。不是所有知识都要立刻加载；把变体、长规范、完整示例拆到 `references/`，并在正文里写清读取条件。

### description 要写触发边界

`description` 不是宣传语，而是触发规则。它应该覆盖：

| 内容 | 示例 |
| --- | --- |
| 任务类型 | code review、docs writing、API debugging |
| 输入信号 | diff、Markdown docs、HTTP error、OpenAPI spec |
| 适用动作 | create、revise、diagnose、verify |
| 不明显场景 | migration guide、release notes、auth failures |

如果一个 Skill 总是不触发，多半是 `description` 太窄或没有写用户真实会说的话。  
如果一个 Skill 经常误触发，多半是 `description` 太泛或名称太通用。

### 不要放 README、CHANGELOG 等无关文件

Skill 目录只放让 Codex 完成任务所需的文件。不要额外创建：

```text
README.md
INSTALLATION_GUIDE.md
QUICK_REFERENCE.md
CHANGELOG.md
```

这些文件通常是给人看的维护资料，会增加噪音。Skill 的使用说明应该在 `SKILL.md`；长参考资料放 `references/`；输出模板放 `assets/`。

### 不要把一次性项目规则误做成 Skill

这些内容不应该做成 Skill：

| 内容 | 原因 |
| --- | --- |
| “本项目不要修改导航文件” | 这是当前任务或仓库规则 |
| “这个 PR 只改一个 bug” | 这是单次任务范围 |
| “今天先不要联网” | 这是当前会话限制 |
| “某个临时接口还没上线” | 这是短期状态，容易过期 |

Skill 应该承载跨任务稳定复用的知识。短期规则越多，Skill 越容易过时，也越容易误导后续任务。

### 验证和迭代要成为习惯

每次更新 Skill 后，至少检查：

| 检查项 | 说明 |
| --- | --- |
| frontmatter 是否至少有 `name` 和 `description` | 普通自定义 Skill 默认只需要这两个字段 |
| `description` 是否覆盖真实请求 | 影响是否能正确触发 |
| `SKILL.md` 是否仍然精简 | 避免上下文膨胀 |
| references 是否可发现 | 正文必须写清什么时候读取 |
| scripts 是否跑过 | 脚本要用实际命令验证 |
| agents/openai.yaml 是否同步 | UI 信息不要和 Skill 内容脱节 |

Skill 不是一次写完就结束。真正好用的 Skill 往往来自几轮真实使用后的删减、改写和拆分。

## 实用范例

下面是三个常见 Skill 的思路骨架。它们不是必须照抄的完整实现，而是展示如何划分 `SKILL.md`、`references/`、`scripts/` 和 `assets/`。

### code-review-style

适合场景：团队希望 Codex 每次代码审查都按固定标准输出，优先找 bug、回归、风险和缺少测试，而不是泛泛夸改动。

目录：

```text
code-review-style/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── references/
    ├── severity.md
    └── review-examples.md
```

`SKILL.md` 骨架：

```markdown
---
name: code-review-style
description: Review code changes with a strict bug-finding style. Use when Codex is asked to review diffs, pull requests, patches, or uncommitted changes and should prioritize correctness, regressions, missing tests, security risks, and file-line findings.
---

# Code Review Style

## Workflow

1. Inspect the diff and relevant surrounding code before writing findings.
2. Prioritize bugs, regressions, security risks, data loss, and missing tests.
3. Report findings first, ordered by severity.
4. Include file and line references for each finding.
5. If there are no findings, say that clearly and mention residual test risk.

## References

- Read `references/severity.md` when severity is ambiguous.
- Read `references/review-examples.md` when output format needs examples.
```

这个 Skill 的重点不是教 Codex 什么是代码审查，而是固定团队想要的审查风格和输出顺序。

### docs-writer

适合场景：项目文档经常需要保持同一风格、同一链接方式和同一验证口径。

目录：

```text
docs-writer/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   ├── style-guide.md
│   └── link-rules.md
└── assets/
    ├── tutorial-template.md
    └── troubleshooting-template.md
```

`SKILL.md` 骨架：

```markdown
---
name: docs-writer
description: Create, revise, and verify repository documentation. Use when Codex needs to write Markdown docs, setup guides, API references, tutorials, troubleshooting pages, migration notes, or release notes while matching an existing documentation style.
---

# Docs Writer

## Workflow

1. Read nearby docs before editing to learn style, structure, and link conventions.
2. Identify the audience and the exact task scope.
3. Draft concise, actionable content with commands and examples only where useful.
4. Avoid uncertain version-sensitive claims unless verified or clearly qualified.
5. Run available Markdown, docs build, or link checks when practical.

## Resources

- Read `references/style-guide.md` for tone and structure rules.
- Read `references/link-rules.md` before adding cross-page links.
- Use `assets/tutorial-template.md` for new tutorial pages.
- Use `assets/troubleshooting-template.md` for troubleshooting pages.
```

这个 Skill 可以把“先看现有文档风格”变成默认动作，减少每次 prompt 里的重复说明。

### api-debugging

适合场景：团队排查 API 问题时希望固定顺序：先确认请求和认证，再看响应、日志、限流和上游依赖，避免直接猜修复。

目录：

```text
api-debugging/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── scripts/
│   └── redact_http_log.py
└── references/
    ├── auth-errors.md
    ├── rate-limits.md
    └── provider-behavior.md
```

`SKILL.md` 骨架：

```markdown
---
name: api-debugging
description: Diagnose API request failures and integration bugs. Use when Codex is asked to debug HTTP errors, authentication failures, response mismatches, webhook issues, rate limits, SDK integration problems, or provider API behavior.
---

# API Debugging

## Workflow

1. Identify the exact request path, method, headers, body shape, environment, and timestamp.
2. Separate client-side construction errors from provider responses and server-side handling.
3. For 401 or 403, read `references/auth-errors.md` before proposing fixes.
4. For 429 or quota errors, read `references/rate-limits.md`.
5. For provider-specific mismatches, read `references/provider-behavior.md`.
6. Redact secrets before showing logs or examples.
7. Prefer minimal reproduction and verified evidence over speculative fixes.

## Scripts

- Use `scripts/redact_http_log.py` before including raw HTTP logs in the final answer.
```

这个 Skill 适合把“不要猜，先分层定位”的排障习惯固化下来。脚本负责稳定脱敏，参考资料负责保存细节，正文只保留流程。

## 一个最小可用 Skill 示例

如果只是想先做一个小 Skill，可以从这个结构开始：

```text
docs-writer/
├── SKILL.md
└── agents/
    └── openai.yaml
```

`SKILL.md`：

```markdown
---
name: docs-writer
description: Create, revise, and verify repository documentation. Use when Codex needs to write or update Markdown docs, setup guides, API references, tutorials, troubleshooting pages, migration notes, or release notes while matching the existing documentation style.
---

# Docs Writer

## Workflow

1. Read nearby documentation before editing.
2. Match the existing page structure, tone, terminology, and link style.
3. State version-sensitive claims carefully; verify them when possible.
4. Prefer concrete steps, examples, and command snippets over broad advice.
5. After editing, check that links, headings, commands, and uncertainty notes still make sense.
```

`agents/openai.yaml`：

```yaml
interface:
  display_name: "Docs Writer"
  short_description: "编写、修订并验证项目文档内容"
  default_prompt: "Use $docs-writer to update the documentation while matching the existing style."
policy:
  allow_implicit_invocation: true
```

这个版本已经可以用。等真实使用时发现资料太长、模板重复或命令固定，再逐步增加 `references/`、`assets/` 或 `scripts/`。

## 创建前的最后判断

创建 Skill 前，可以用这张表快速决策：

| 问题 | 如果答案是“是” |
| --- | --- |
| 这套流程会被多次复用吗？ | 可以考虑 Skill |
| 是否需要 Codex 按固定步骤工作？ | 写进 `SKILL.md` |
| 是否有长资料会反复用到？ | 放进 `references/` |
| 是否有确定性脚本能减少错误？ | 放进 `scripts/` |
| 是否有固定输出模板或素材？ | 放进 `assets/` |
| 是否只是当前项目或当前任务规则？ | 不要做成 Skill |

结论很直接：Skill 的价值不在“多写一层配置”，而在把重复、稳定、容易遗漏的任务知识变成 Codex 可以自动带上的能力。小而清晰的 Skill 通常比大而全的 Skill 更可靠，也更容易迭代。
