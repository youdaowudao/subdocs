# Mac ChatGPT 桌面版中文化

这个工具给 Mac 上官方 ChatGPT 应用里的 Codex 启用内置的界面翻译，适合已选择简体中文但仍显示英文的用户。只写本机语言缓存，不修改 `config.toml` 或账号配置。

在 ChatGPT 外部的「终端」运行下面这条命令。电脑需要已有可用的 Python 3.9 或更新版本；默认应用位置为 `/Applications/ChatGPT.app`。

```sh
curl -fsSL https://docs.usegoodai.com/install/chinese.sh | /bin/bash
```

命令先关闭应用，再临时打开 ChatGPT 写入缓存。窗口出现属于上游原有流程，终端会显示中文阶段提示，等待超过 5 秒时继续报告进度。完成后关闭临时窗口，请自己重新打开 ChatGPT；失败和中断也执行关闭收尾。

1.1.3 保留上游 Mac 提供的 `--app`、`--port` 和 `--timeout` 参数；单文件封装通过 `bash -s -- 参数` 传入。正式发布状态以版本记录为准。

## 来源与本次修改

启动入口和 WebSocket 协议采用 `zhenglei410/codex-i18n-cache-seeder-macos` 的 `346c43e4b977aaa58f3a0b2ffbb8b54729312904`。页面写入、刷新校验和两次复查直接由构建脚本提取 Windows current-key 核心，不继续使用旧版多缓存键算法或共享 `language-cache.js`。Statsig 等待上限保持 60 秒；超时仍失败，不新增强行写入。

对应 Windows 的四处接入以 `# UseGoodAI：` 标明：开头复用既有 SIGTERM 等 5 秒、SIGKILL 后复查的关闭逻辑；结束不重开；单文件内嵌核心；关闭前请求 App 正常退出以保存缓存；失败时仍复用既有关闭逻辑清理，并明确报错。另复用本次 Windows 已确认需要的中文阶段提示、每 5 秒进度、总等待超时和明确页面失效重连；主动刷新本身不重试。去掉旧版 app-server 写桌面语言和配置备份的步骤。缓存算法没有改写。

1.1.3 先请求目标 App 正常退出，确认主进程消失；原 TERM/KILL、页面和后台进程清理作兜底。正常退出失败时不报成功。后台进程收尾按真实路径、当前用户和父子关系限定范围，独立命令行进程保留。原版决定语言来源；缓存来源为 SYSTEM 时按系统语言工作，测试中不能将英文系统直接当成中文系统。

源码为本目录 `chinese.py`；`build.py` 生成上层 `install/chinese.sh` 和站点 `docs/public/install/chinese.sh`，`--check` 核对两份字节。实机、重复运行、普通重开及缓存落盘结果见版本记录和 `test-records/20261120-codex-chinese.md`。
