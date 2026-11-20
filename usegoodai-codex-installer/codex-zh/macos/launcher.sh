#!/bin/sh

if [ "$(/usr/bin/uname -s)" != Darwin ]; then
    printf '%s\n' '这条命令用于 macOS 上的 ChatGPT 桌面应用。' >&2
    exit 1
fi

python_path="$(command -v python3 || true)"
if [ -z "$python_path" ] ||
   { [ "$python_path" = /usr/bin/python3 ] && ! /usr/bin/xcode-select -p >/dev/null 2>&1; } ||
   ! "$python_path" -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
    printf '%s\n' '需要可用的 Python 3.9 或更新版本。本次没有修改 ChatGPT。' >&2
    exit 1
fi

# UseGoodAI：单文件封装保留上游的应用路径、端口和等待时间参数。
exec "$python_path" - "$@"
