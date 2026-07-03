# Codex 日志高频写盘 bug 处理

## 省流版

把下面这段直接复制给 AI：

```text
帮我检查 Windows 默认 Codex 日志库：

%USERPROFILE%\.codex\logs_2.sqlite

是否因 TRACE 日志持续高频写盘。

如果存在高频写盘，用 SQLite trigger 拦截 logs 表 insert，
确认 MAX(id) 和 WAL 下 trace/debug/info 级日志不再增长。
```

## 这是什么问题

Codex 会把运行日志写到 `%USERPROFILE%\.codex\logs_2.sqlite`。部分版本会持续写入大量 `TRACE` 日志，表现为 `logs_2.sqlite-wal` 频繁刷新，`logs` 表的 `MAX(id)` 不断增加。

这个问题和聊天记录不是一回事，主要是运行日志高频落盘。截至 `2026-07-03`，当前最新版本 `@openai/codex 0.142.5` 仍未从软件侧解决，所以可以先用 SQLite trigger 做本地拦截。

## 注意事项

这个方法只阻止后续 `TRACE / DEBUG / INFO` 继续写入，不会自动缩小已经变大的 `logs_2.sqlite`。如果数据库已经有几个 GB，后续还要单独清理或压缩。
