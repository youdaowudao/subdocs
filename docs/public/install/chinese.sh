#!/bin/sh
# UseGoodAI Codex 中文化 Mac 1.0.0
# MIT License
#
# Copyright (c) 2026 zhenglei410
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [ "$(/usr/bin/uname -s)" != Darwin ]; then
    printf '%s\n' '这条命令用于 macOS 上的 Codex 桌面应用。' >&2
    exit 1
fi

python_path="$(command -v python3 || true)"
if [ -z "$python_path" ] ||
   { [ "$python_path" = /usr/bin/python3 ] && ! /usr/bin/xcode-select -p >/dev/null 2>&1; } ||
   ! "$python_path" -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
    printf '%s\n' '需要可用的 Python 3.9 或更新版本。本次没有修改 Codex。' >&2
    exit 1
fi

exec "$python_path" - <<'USEGOODAI_CODEX_CHINESE_PYTHON'
"""UseGoodAI macOS Codex desktop language command."""
import base64
import hashlib
import http.client
import json
import os
from pathlib import Path
import plistlib
import re
import select
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit


CACHE_EXPRESSION = "// The expression runs in the official Codex renderer through Electron CDP.\n(async (write, timeoutMs) => {\n    const until = Date.now() + timeoutMs;\n    let client;\n    do {\n        const root = globalThis.__STATSIG__;\n        client = root?.firstInstance ?? root?.instance?.();\n        if (client?.loadingStatus === 'Ready') break;\n        await new Promise(resolve => setTimeout(resolve, 200));\n    } while (Date.now() < until);\n    if (client?.loadingStatus !== 'Ready' || typeof client.dataAdapter?._getCacheKey !== 'function') {\n        throw new Error('Statsig did not become ready or has an unsupported cache adapter.');\n    }\n\n    const context = client.getContext();\n    const cacheKey = client.dataAdapter._getCacheKey(context.user);\n    if (typeof cacheKey !== 'string' || !cacheKey.startsWith('statsig.cached.evaluations.')) {\n        throw new Error('Unrecognized Statsig cache key.');\n    }\n\n    const cacheText = localStorage.getItem(cacheKey);\n    const wrapper = cacheText === null ? null : JSON.parse(cacheText);\n    if (cacheText !== null && (!wrapper || typeof wrapper !== 'object' || Array.isArray(wrapper))) {\n        throw new Error('Invalid existing Statsig cache record.');\n    }\n    const stringData = typeof wrapper?.data === 'string';\n    let payload = wrapper ? (stringData ? JSON.parse(wrapper.data) : wrapper.data) : null;\n    if (write && cacheText === null) {\n        if (context.values?.has_updates === true) {\n            payload = JSON.parse(JSON.stringify(context.values));\n        } else {\n            // The upstream bootstrap format is used only for a missing current key.\n            payload = {\n                has_updates: true,\n                response_format: 'init-v2',\n                time: Date.now(),\n                feature_gates: {},\n                dynamic_configs: {},\n                layer_configs: { '72216192': { v: '0', r: 'usegoodai-codex-zh', s: [], is_device_based: true } },\n                values: { '0': { enable_i18n: true, locale_source: 'IDE' } },\n                param_stores: {},\n                sdk_flags: {},\n                exposures: {}\n            };\n        }\n    }\n    if (!payload || typeof payload.layer_configs !== 'object' || payload.layer_configs === null) {\n        throw new Error('No supported Statsig evaluations are available for the current client.');\n    }\n\n    const knownLayers = ['72216192', '4269166702'].filter(key =>\n        Object.prototype.hasOwnProperty.call(payload.layer_configs, key));\n    if (knownLayers.length !== 1) {\n        throw new Error('The localization layer could not be identified unambiguously.');\n    }\n    const layerKey = knownLayers[0];\n    const layer = payload.layer_configs[layerKey];\n    if (!layer || typeof layer !== 'object' || Array.isArray(layer)) {\n        throw new Error('Unsupported localization layer.');\n    }\n\n    const value = layer.v !== undefined ? payload.values?.[String(layer.v)] : (layer.value ?? layer);\n    if (!value || typeof value.enable_i18n !== 'boolean') {\n        throw new Error('The localization flag is missing or invalid.');\n    }\n\n    if (write && (!wrapper || value.enable_i18n !== true)) {\n        if (layer.v !== undefined && value.enable_i18n !== true) {\n            // Layer value slots can be shared with unrelated evaluations.\n            let index = 0;\n            while (Object.prototype.hasOwnProperty.call(payload.values, String(index))) index += 1;\n            payload.values[String(index)] = { ...value, enable_i18n: true };\n            layer.v = String(index);\n        } else {\n            value.enable_i18n = true;\n        }\n        const record = wrapper ?? {\n            source: 'Bootstrap',\n            receivedAt: Date.now(),\n            stableID: context.stableID ?? null,\n            fullUserHash: null\n        };\n        record.data = wrapper && !stringData ? payload : JSON.stringify(payload);\n        localStorage.setItem(cacheKey, JSON.stringify(record));\n    }\n\n    const live = client.getLayer?.('72216192', { disableExposureLog: true })?.get('enable_i18n', null);\n    return { enabled: write || value.enable_i18n === true, liveEnabled: live === true };\n})"
BUNDLE_ID = "com.openai.codex"
TEAM_ID = "2DC432GLL2"
LOOPBACK = "127.0.0.1"


def run(*arguments):
    return subprocess.run(arguments, capture_output=True, text=True, timeout=20)


def find_app():
    for directory in (Path("/Applications"), Path.home() / "Applications"):
        for name in ("ChatGPT.app", "Codex.app"):
            app = (directory / name).resolve()
            info_path = app / "Contents/Info.plist"
            if not info_path.is_file():
                continue
            with info_path.open("rb") as plist:
                info = plistlib.load(plist)
            if info.get("CFBundleIdentifier") != BUNDLE_ID:
                continue
            name = info.get("CFBundleExecutable", "")
            if name not in ("ChatGPT", "Codex"):
                raise RuntimeError("官方应用的启动入口无法识别。")
            requirement = f'anchor apple generic and identifier "{BUNDLE_ID}" and certificate leaf[subject.OU] = "{TEAM_ID}"'
            if run("/usr/bin/codesign", "--verify", "--strict", "-R", requirement, str(app)).returncode:
                raise RuntimeError("无法验证已安装 Codex 的官方签名。")
            executable = app / "Contents/MacOS" / name
            backends = (
                app / "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
                app / "Contents/Resources/codex",
            )
            backend = next((p for p in backends if p.is_file() and os.access(p, os.X_OK)), None)
            if not executable.is_file() or backend is None:
                raise RuntimeError("无法找到官方 Codex 桌面程序或内置命令。")
            return app, executable, backend
    raise RuntimeError("未在应用程序文件夹找到官方 Codex 桌面应用。")


def process_snapshot():
    result = run("/bin/ps", "-ww", "-axo", "pid=,ppid=,uid=,stat=,comm=")
    result.check_returncode()
    return {
        int(pid): (int(parent), int(uid), state, name)
        for line in result.stdout.splitlines()
        if len(parts := line.strip().split(None, 4)) == 5
        for pid, parent, uid, state, name in [parts]
    }


def matching(rows, executable):
    return {
        pid for pid, (_, uid, state, path) in rows.items()
        if uid == os.getuid() and not state.startswith("Z") and path == str(executable)
    }


def running(executable):
    return matching(process_snapshot(), executable)


def own_ancestors(rows):
    current = os.getpid()
    ancestors = set()
    while current in rows and current not in ancestors:
        ancestors.add(current)
        current = rows[current][0]
    return ancestors


def signal_matching(executable, pids, kind):
    for pid in running(executable).intersection(pids):
        try:
            os.kill(pid, kind)
        except ProcessLookupError:
            pass


def wait_until(action, timeout):
    end = time.monotonic() + timeout
    while True:
        result = action()
        if result:
            return result
        if time.monotonic() >= end:
            return None
        time.sleep(0.25)


def stop(executable, pids):
    if not pids:
        return
    # Same TERM, wait, KILL and recheck sequence as the project's Mac installer.
    signal_matching(executable, pids, signal.SIGTERM)
    if wait_until(lambda: not (running(executable) & pids), 5):
        return
    signal_matching(executable, pids, signal.SIGKILL)
    if not wait_until(lambda: not (running(executable) & pids), 2):
        raise RuntimeError("Codex 未能退出。请从应用菜单彻底退出后重试。")


def open_app(app, *arguments):
    args = ["/usr/bin/open", "-a", str(app)]
    if arguments:
        args.extend(("--args", *arguments))
    if run(*args).returncode:
        raise RuntimeError("macOS 未能打开 Codex。")


def write_language(backend):
    launch_home = run("/bin/launchctl", "getenv", "CODEX_HOME").stdout.rstrip("\n")
    config_home = Path(launch_home).expanduser() if launch_home else Path.home() / ".codex"
    configuration = config_home / "config.toml"
    if not config_home.is_absolute() or configuration.is_symlink():
        raise RuntimeError("无法安全确认 Codex 配置路径。")
    old = configuration.read_bytes() if configuration.is_file() else None
    backup = None
    if old is not None:
        with tempfile.NamedTemporaryFile(prefix="config.toml.codex-zh.bak.", dir=config_home, delete=False) as file:
            file.write(old)
            backup = Path(file.name)
    buffer = b""
    with subprocess.Popen(
        [str(backend), "app-server", "--listen", "stdio://"],
        cwd=str(Path.home()), env=dict(os.environ, CODEX_HOME=str(config_home)),
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    ) as child:
        def send(message):
            child.stdin.write(json.dumps(message).encode() + b"\n")
            child.stdin.flush()

        def response(request_id):
            nonlocal buffer
            end = time.monotonic() + 15
            while time.monotonic() < end:
                if b"\n" not in buffer:
                    ready, _, _ = select.select([child.stdout], [], [], max(0, end - time.monotonic()))
                    if not ready:
                        break
                    part = os.read(child.stdout.fileno(), 65536)
                    if not part or len(buffer) + len(part) > 2 * 1024 * 1024:
                        break
                    buffer += part
                    continue
                line, buffer = buffer.split(b"\n", 1)
                row = json.loads(line)
                if row.get("id") == request_id:
                    if "error" in row:
                        raise RuntimeError("官方 Codex 未能写入或读取桌面语言配置。")
                    return row.get("result", {})
            raise RuntimeError("等待官方 Codex 配置程序超时。")

        try:
            send({"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "usegoodai-codex-zh", "version": "1.0"}}})
            response(1)
            send({"method": "initialized"})
            send({"id": 2, "method": "config/value/write", "params": {
                "keyPath": "desktop.localeOverride", "value": "zh-CN", "mergeStrategy": "upsert",
                "filePath": str(configuration),
            }})
            saved = response(2)
            if saved.get("status") != "ok" or Path(saved.get("filePath", "")).resolve() != configuration.resolve():
                raise RuntimeError("无法确认已写入当前 Codex 的语言偏好。")
            send({"id": 3, "method": "config/read", "params": {"includeLayers": False}})
            if response(3).get("config", {}).get("desktop", {}).get("localeOverride") != "zh-CN":
                raise RuntimeError("Codex 未回读到简体中文偏好。")
        finally:
            child.stdin.close()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=3)
    if backup and configuration.read_bytes() == old:
        backup.unlink()


def read_exact(stream, size):
    value = stream.read(size)
    if len(value) != size:
        raise RuntimeError("Codex 调试连接中途关闭。")
    return value


# Adapted from the upstream macOS standard-library WebSocket transport.
def evaluate(url, port, method, params):
    address = urlsplit(url)
    if (address.scheme != "ws" or address.hostname not in (LOOPBACK, "localhost")
            or address.port != port or address.query or address.fragment
            or not re.fullmatch(r"/devtools/page/[A-Za-z0-9_-]+", address.path)):
        raise RuntimeError("Codex 返回了无法验证的调试地址。")
    key = base64.b64encode(os.urandom(16)).decode()
    accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
    request = (f"GET {address.path} HTTP/1.1\r\nHost: {LOOPBACK}:{port}\r\n"
               f"Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
               "Sec-WebSocket-Version: 13\r\n\r\n")

    with socket.create_connection((LOOPBACK, port), timeout=12) as connection:
        with connection.makefile("rb") as stream:
            connection.sendall(request.encode("ascii"))
            if not stream.readline(4096).startswith(b"HTTP/1.1 101 "):
                raise RuntimeError("无法连上 Codex 调试窗口。")
            headers = {}
            for _ in range(40):
                line = stream.readline(4096)
                if line == b"\r\n":
                    break
                name, separator, value = line.partition(b":")
                if not separator:
                    raise RuntimeError("Codex 的调试握手响应无效。")
                headers[name.lower()] = value.strip()
            if headers.get(b"sec-websocket-accept") != accept:
                raise RuntimeError("Codex 的调试握手校验失败。")

            def send(opcode, data):
                size = len(data)
                mask = os.urandom(4)
                length = bytes([128 | size]) if size < 126 else bytes([254]) + struct.pack("!H", size)
                connection.sendall(bytes([128 | opcode]) + length + mask +
                                   bytes(value ^ mask[index % 4] for index, value in enumerate(data)))

            send(1, json.dumps({"id": 1, "method": method, "params": params}).encode())
            fragments = bytearray()
            end = time.monotonic() + 15
            while time.monotonic() < end:
                connection.settimeout(max(0.1, end - time.monotonic()))
                flags, size_byte = read_exact(stream, 2)
                size = size_byte & 127
                if size == 126:
                    size = struct.unpack("!H", read_exact(stream, 2))[0]
                elif size == 127:
                    size = struct.unpack("!Q", read_exact(stream, 8))[0]
                if size_byte & 128 or len(fragments) + size > 1024 * 1024:
                    raise RuntimeError("Codex 调试响应无效或过大。")
                data = read_exact(stream, size)
                opcode = flags & 15
                if opcode == 8:
                    raise RuntimeError("Codex 已关闭调试连接。")
                if opcode == 9:
                    send(10, data)
                if opcode not in (0, 1):
                    continue
                fragments.extend(data)
                if not flags & 128:
                    continue
                response = json.loads(fragments)
                fragments.clear()
                if response.get("id") != 1:
                    continue
                result = response.get("result", {})
                if "error" in response or "exceptionDetails" in result:
                    raise RuntimeError("Codex 界面未能读写语言缓存。")
                return result
    raise RuntimeError("等待 Codex 调试响应超时。")


def debug_pids(executable, port):
    flag = f"--remote-debugging-port={port}"
    return {
        pid for pid in running(executable)
        if flag in run("/bin/ps", "-ww", "-p", str(pid), "-o", "command=").stdout.split()
    }


def debug_target(executable, port):
    expected = debug_pids(executable, port)
    if not expected:
        return None
    fields = run("/usr/sbin/lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-Fpn").stdout.splitlines()
    if not fields:
        return None
    owner = None
    for field in fields:
        if field.startswith("p"):
            owner = int(field[1:])
        elif field.startswith("n") and (owner not in expected or field[1:] not in (f"{LOOPBACK}:{port}", f"[::1]:{port}")):
            raise RuntimeError("调试端口的进程或监听地址不符合预期。")
    http = http.client.HTTPConnection(LOOPBACK, port, timeout=2)
    try:
        http.request("GET", "/json/list")
        reply = http.getresponse()
        targets = json.loads(reply.read(1024 * 1024)) if reply.status == 200 else []
    except (OSError, http.client.HTTPException, ValueError):
        return None
    finally:
        http.close()
    return next((page["webSocketDebuggerUrl"] for page in targets
                 if page.get("url") == "app://-/index.html" and page.get("type") == "page"
                 and page.get("webSocketDebuggerUrl")), None)


def cache_call(target, port, write):
    mode = "true" if write else "false"
    expression = f"({CACHE_EXPRESSION}\n)({mode}, 8000)"
    result = evaluate(target, port, "Runtime.evaluate",
                      {"expression": expression, "awaitPromise": True, "returnByValue": True})
    return result.get("result", {}).get("value", {})


def repair():
    app, executable, backend = find_app()
    rows = process_snapshot()
    original = matching(rows, executable)
    if original.intersection(own_ancestors(rows)):
        raise RuntimeError("请在 Codex 外部的终端运行。")
    if original:
        print("正在关闭 Codex 桌面应用……", flush=True)
    stop(executable, original)
    if running(executable):
        raise RuntimeError("Codex 被其他程序重新打开，请退出后再运行。")

    port = None
    owned_debug = set()
    try:
        write_language(backend)
        if running(executable):
            raise RuntimeError("Codex 被其他程序重新打开，请退出后再运行。")
        with socket.socket() as listener:
            listener.bind((LOOPBACK, 0))
            port = listener.getsockname()[1]
        open_app(app, f"--remote-debugging-port={port}",
                 f"--remote-allow-origins=http://{LOOPBACK}:{port}")
        target = wait_until(lambda: debug_target(executable, port), 30)
        owned_debug = debug_pids(executable, port)
        if not target:
            raise RuntimeError("等待官方 Codex 调试窗口超时。")
        if not cache_call(target, port, True).get("enabled"):
            raise RuntimeError("未写入 Codex 的语言缓存。")
        evaluate(target, port, "Page.reload", {})

        def verify():
            try:
                url = debug_target(executable, port)
                result = cache_call(url, port, False) if url else {}
                return result.get("enabled") and result.get("liveEnabled")
            except (OSError, RuntimeError):
                return False

        if not wait_until(verify, 15):
            raise RuntimeError("刷新后未能确认 Codex 读取了语言缓存。")
    finally:
        if port is not None:
            if not owned_debug:
                owned_debug = wait_until(lambda: debug_pids(executable, port), 3) or set()
            stop(executable, owned_debug | debug_pids(executable, port))
            if not wait_until(lambda: not debug_pids(executable, port), 3):
                raise RuntimeError("临时调试实例仍在运行，请退出 Codex 后正常重新打开。")
        if not running(executable):
            open_app(app)
        if not wait_until(lambda: running(executable), 20):
            raise RuntimeError("未能确认 Codex 正常重新打开。")
        if port is not None and debug_pids(executable, port):
            raise RuntimeError("Codex 仍以调试模式运行，请退出后正常重新打开。")
    print("已启用语言开关并设置简体中文。请查看重新打开的 Codex 菜单。")


def interrupted(_signum, _frame):
    raise KeyboardInterrupt()


if __name__ == "__main__":
    signal.signal(signal.SIGHUP, interrupted)
    signal.signal(signal.SIGTERM, interrupted)
    try:
        repair()
    except KeyboardInterrupt:
        print("已中断。", file=sys.stderr)
        sys.exit(130)
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"错误：{error}", file=sys.stderr)
        sys.exit(1)
USEGOODAI_CODEX_CHINESE_PYTHON
