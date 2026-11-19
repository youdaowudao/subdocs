# Codex 桌面版中文化（Windows）

照搬上游 [zhenglei410/codex-i18n-cache-seeder](https://github.com/zhenglei410/codex-i18n-cache-seeder) 的 `current-key` 两个脚本（GitHub 提交 `feb1239c5acf`），文件名保持一致，便于逐行对照。只改了以下四处，均以 `# UseGoodAI：` 注释标出：

1. 关闭 ChatGPT/Codex 改用 `install/codex.ps1` 的 `Stop-RunningClients`（原样复制），入口开头和写完缓存后都用它；关完沿用上游做法，等系统进程列表里当前用户的 ChatGPT/Codex 进程清空，最多 10 秒。复制来的 `Get-OwnProcessIds` 加了启动时间判断：Windows 会复用已退出进程的编号，原函数可能把复用了编号的 ChatGPT.exe 当成自己的父进程而漏关（实测）。
2. 取消自动重启：写入并验证缓存、按上游等待两次各 3 秒后，只关闭调试实例，提示用户自己重新打开 Codex。
3. 核心脚本不再运行时从 Gitee 下载，`build.py` 生成发布文件时原样嵌入。
4. 关闭调试实例前先结束 Codex 的页面进程（renderer）并等 2 秒。Windows 实测上游直接强制结束会丢失尚未写入磁盘的缓存，提示成功但重开仍是英文；页面进程全部断开后 Chromium 会立即写盘。

其余流程与上游一致：用 9240 端口启动调试实例，等待 Statsig 就绪，写入当前缓存键并修补其它已有缓存键，刷新页面后读本地缓存确认。

## 使用

在 Codex 外部打开 PowerShell，运行：

```powershell
irm https://docs.usegoodai.com/install/chinese.ps1 | iex
```

显示「[成功]」后重新打开 Codex。

## 维护

修改 `windows/` 下两个脚本后运行 `python3 codex-zh/build.py` 生成两份发布副本，`--check` 核对字节一致。
