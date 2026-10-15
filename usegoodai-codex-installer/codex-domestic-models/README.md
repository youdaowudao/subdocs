# 给 Codex 导入国产模型

这个脚本供已经通过 UseGoodAI 使用 GPT 的 Codex 用户导入 8 个国产模型，GPT 与国产模型并列可选。它只修改用户配置目录的 `config.toml` 中两项设置，并生成完整的本地模型目录；默认模型、接口、Key 和其他配置继续保留。

当前交付物是 [Windows 脚本](install/codex-models.ps1) 和 [Linux/macOS 共用脚本](install/codex-models.sh)。源码、设定和测试都在本子项目；交付物按用户要求迁移到上级安装目录与站点发布目录，供用户实机测试。

## 运行脚本

成功导入后会自动关闭 ChatGPT/Codex，正在运行的任务会中断。重新运行同一入口就是更新模型。

Windows 在 PowerShell 中执行：

```powershell
& .\install\codex-models.ps1
```

Linux/macOS 在终端执行，脚本自动识别系统：

```bash
bash install/codex-models.sh
```

重新打开 Codex，新建任务，选择 GPT 或国产模型。测试消息写“测试”；分组由用户在中转站切换。

脚本读取 `CODEX_HOME`；未设置时使用用户的 `.codex`。桌面 App 与命令行共用这里的模型目录。Windows 用 `-CodexPath`、Linux/macOS 用 `--codex-path` 指定现有 Codex 后端；配置目录参数分别为 `-CodexHomePath` 和 `--codex-home`。

macOS 自动定位 App 后端；Linux 优先读取正在运行的 App 后端，未找到时使用本机已有的 `codex` 命令。Linux 使用已有 Node.js 16+ 执行相同的模型处理逻辑，缺少时明确提示并退出，不自动安装依赖。

找不到 App 后端、目录无效、默认模型不在目录或写入失败时，停止导入并保留或恢复原文件，软件不会被关闭。`desktop` 使用内联表或 profile 覆盖模型目录时，脚本会说明需要整理的位置，再停止写入。

Linux/macOS 失败时直接显示失败步骤、涉及的文件或后端命令、具体原因及可用的错误码；Linux 后端失败同时显示退出码。JSON 错误只显示行列或字符位置，后端错误只提取已识别的安全原因，不输出配置片段、Key 或完整原始异常。

## 维护名单和生成交付物

唯一的模型名单和差异设定在 [src/models.json](src/models.json)，包含精确 ID、显示名、上下文、输入能力和推理档位。共同的 Codex 元数据由 [build.py](build.py) 补齐；不能把某个 GPT 对象复制改名当作国产元数据。

```bash
python3 build.py
```

生成的两个脚本内嵌同一份数据，不依赖相邻文件，支持下载执行或管道执行。Windows 使用内置 PowerShell，macOS 使用内置 JXA，Linux 使用已有 Node.js；Linux/macOS 共用同一份 JavaScript 模型处理核心。脚本不自动安装运行环境或另一份 Codex。

进程检测、祖先排除、结束和结果报告在构建时直接从上级 `install/codex.ps1`、`install/codex.sh` 取出。测试核对生成结果与原函数一致。

模型能力依据和保守设置见 [元数据来源](元数据来源.md)。`minimax-m3` 保留已确定的小写请求 ID，正式中转站别名仍需发布者核对；脚本不更改大小写。

## 运行开发测试

开发测试使用 Python 3.11+、Node、PowerShell 和 Codex 后端。当前 Linux 测试工具放在忽略的 `.dev-tools` 中，版本为 Node 22.20.0、PowerShell 7.6.7、Codex 0.162.1；测试入口也支持 `TEST_NODE`、`TEST_PWSH`、`TEST_CODEX` 指定已有工具的绝对路径。这些工具只用于开发验证。

```bash
python3 tests/test_models.py
```

测试只在 `tests/.work/` 内创建配置、模拟数据和输出，读取本子项目源码；进程测试拦截终止操作。目录合并用例同时经过 JavaScript 和 PowerShell，修改结果再由 Python 标准 TOML 解析器校验；集成测试调用真正的 Codex 后端。

完整结果及未执行的实机检查见 [测试记录](测试记录.md)。独立代码审查见 [审阅记录](审阅记录.md)。

## 配置持久化和恢复

生成 `usegoodai-models.json` 与 `usegoodai-models.managed.json`，前者保存完整模型元数据，后者只记录本工具管理的模型 ID。修改前在同目录生成带时间和随机后缀的 `.bak` 备份；用户原来指向其他位置的模型目录继续保留。

文件位于用户配置目录，正常 App 升级继续使用，不设置后台程序或升级任务。静态目录不会自动加入将来的 GPT；主动重新运行可以从该 App 补齐新增条目。再次运行原 GPT 接入脚本覆盖配置后，重新运行本导入脚本恢复目录指向。

需要撤销本次导入时，关闭 App，把本次 `config.toml.bak.*` 复制回 `config.toml`；原来已经使用本工具目录时，同时恢复本次 `usegoodai-models.json.bak.*` 和管理记录备份。重新打开 App 后新建任务验证。

## 开发者迁移发布

本次用户要求先发布入口并自行实机测试，因此已手动迁移 `install/codex-models.ps1`、`install/codex-models.sh` 到上级 `usegoodai-codex-installer/install/` 和站点 `docs/public/install/`。发布入口分别是 `https://docs.usegoodai.com/install/codex-models.ps1` 与 `https://docs.usegoodai.com/install/codex-models.sh`。实机验收状态仍以测试记录为准。

后续继续在本子项目开发、构建和测试，再复制两个交付物到同样位置。保留完整源码与审阅、测试记录；站点测试检查三处脚本逐字节一致，原 GPT 安装入口继续使用原文件名。
