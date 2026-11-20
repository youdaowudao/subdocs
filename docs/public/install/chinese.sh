#!/bin/sh
# UseGoodAI Codex 中文化 Mac 1.1.0
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
exec "$python_path" - "$@" <<'USEGOODAI_CODEX_CHINESE_PYTHON'
#!/usr/bin/env python3
"""Seed the Codex Statsig i18n cache via a temporary local CDP connection."""
import argparse, base64, hashlib, json, os, socket, struct, subprocess, sys, time, urllib.request
from urllib.parse import urlsplit
from contextlib import contextmanager
import re, signal, threading

# UseGoodAI：构建时嵌入 Windows current-key 原版页面脚本及原版刷新校验，运行时不下载核心。
EXPRESSION = '(async () => {\n    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));\n    const inspectOnly = __INSPECT_ONLY__;\n    const noBootstrap = __NO_BOOTSTRAP__;\n    const patchAllExisting = __PATCH_ALL_EXISTING__;\n    const targetLayer = "72216192";\n    const targetLayerHash = "4269166702";\n    const cachePrefix = "statsig.cached.evaluations.";\n    const deadline = Date.now() + __READY_TIMEOUT_MS__;\n\n    const getRoot = () => window.__STATSIG__ || globalThis.__STATSIG__;\n    const getClient = () => {\n        const root = getRoot();\n        if (!root) return null;\n        return root.firstInstance ||\n            (typeof root.instance === "function" ? root.instance() : null);\n    };\n\n    let client = getClient();\n    while (\n        (!client || String(client.loadingStatus || "") !== "Ready") &&\n        Date.now() < deadline\n    ) {\n        await sleep(250);\n        client = getClient();\n    }\n\n    if (!client) {\n        return JSON.stringify({\n            ok: false,\n            error: "ChatGPT 配置服务未能启动。",\n            origin: location.origin,\n            href: location.href,\n            hasStatsigRoot: Boolean(getRoot())\n        });\n    }\n\n    if (String(client.loadingStatus || "") !== "Ready") {\n        return JSON.stringify({\n            ok: false,\n            error: "等待 ChatGPT 配置服务超过 60 秒，尚未就绪。",\n            origin: location.origin,\n            href: location.href,\n            htmlLang: document.documentElement.lang,\n            statsigStatus: client.loadingStatus\n        });\n    }\n\n    const context = client.getContext();\n    const currentCacheKey = String(client.dataAdapter._getCacheKey(context.user));\n\n    const allCacheKeys = Object.keys(localStorage)\n        .filter(key => key.startsWith(cachePrefix));\n    const staleCacheKeys = allCacheKeys\n        .filter(key => key !== currentCacheKey);\n\n    const layer = client.getLayer(targetLayer, { disableExposureLog: true });\n    const liveEnableI18n = layer ? layer.get("enable_i18n", null) : null;\n    const currentCacheValue = localStorage.getItem(currentCacheKey);\n\n    if (inspectOnly) {\n        return JSON.stringify({\n            ok: true,\n            mode: "inspect",\n            origin: location.origin,\n            href: location.href,\n            htmlLang: document.documentElement.lang,\n            statsigStatus: client.loadingStatus,\n            currentCacheKey,\n            currentCacheKeyExists: currentCacheValue !== null,\n            allCacheKeys,\n            staleCacheKeys,\n            patchAllExisting,\n            liveEnableI18n\n        });\n    }\n\n    const parseCurrentPayload = () => {\n        if (currentCacheValue === null) return null;\n        const wrapper = JSON.parse(currentCacheValue);\n        const dataWasString = typeof wrapper.data === "string";\n        const payload = dataWasString ? JSON.parse(wrapper.data) : wrapper.data;\n        return { wrapper, payload, dataWasString };\n    };\n\n    let parsed = null;\n    try {\n        parsed = parseCurrentPayload();\n    }\n    catch {\n        parsed = null;\n    }\n\n    let wrapper = parsed?.wrapper ?? null;\n    let dataWasString = parsed?.dataWasString ?? true;\n    let payload = parsed?.payload ?? null;\n    let seededFrom = parsed ? "current-cache" : null;\n\n    if (!payload && context.values && context.values.has_updates === true) {\n        payload = JSON.parse(JSON.stringify(context.values));\n        seededFrom = "context-values";\n    }\n\n    if (!payload && !noBootstrap) {\n        payload = {\n            has_updates: true,\n            response_format: "init-v2",\n            time: Date.now(),\n            feature_gates: {},\n            dynamic_configs: {},\n            layer_configs: {},\n            values: {},\n            param_stores: {},\n            sdk_flags: {},\n            exposures: {}\n        };\n        seededFrom = "minimal-bootstrap";\n    }\n\n    if (!payload) {\n        return JSON.stringify({\n            ok: false,\n            error: "当前语言缓存不存在，且未启用补建缓存。",\n            currentCacheKey,\n            allCacheKeys,\n            staleCacheKeys,\n            liveEnableI18n\n        });\n    }\n\n    const hasOwn = (value, key) =>\n        value !== null &&\n        typeof value === "object" &&\n        Object.prototype.hasOwnProperty.call(value, key);\n\n    const patchExistingLayer = targetPayload => {\n        const layerMap = targetPayload?.layer_configs;\n        const values = targetPayload?.values;\n        if (!layerMap || typeof layerMap !== "object") return false;\n\n        for (const [name, metadata] of Object.entries(layerMap)) {\n            if (!metadata || typeof metadata !== "object") continue;\n\n            const isTarget = name === targetLayer || name === targetLayerHash;\n            const candidates = [];\n            if (metadata.v !== undefined && values && typeof values === "object") {\n                candidates.push(values[String(metadata.v)]);\n            }\n            if (metadata.value && typeof metadata.value === "object") {\n                candidates.push(metadata.value);\n            }\n            if (isTarget) candidates.push(metadata);\n\n            for (const candidate of candidates) {\n                if (candidate && hasOwn(candidate, "enable_i18n")) {\n                    candidate.enable_i18n = true;\n                    if (!hasOwn(candidate, "locale_source")) {\n                        candidate.locale_source = "SYSTEM";\n                    }\n                    return true;\n                }\n            }\n        }\n\n        return false;\n    };\n\n    const insertI18nLayer = targetPayload => {\n        targetPayload.has_updates = true;\n        targetPayload.layer_configs = targetPayload.layer_configs || {};\n\n        if (targetPayload.response_format === "init-v2" || targetPayload.values) {\n            targetPayload.response_format = "init-v2";\n            targetPayload.values = targetPayload.values || {};\n            let index = 0;\n            while (hasOwn(targetPayload.values, String(index))) index += 1;\n            targetPayload.values[String(index)] = {\n                enable_i18n: true,\n                locale_source: "SYSTEM"\n            };\n            targetPayload.layer_configs[targetLayer] = {\n                v: String(index),\n                r: "codex-current-key",\n                s: [],\n                is_device_based: true\n            };\n        }\n        else {\n            targetPayload.layer_configs[targetLayer] = {\n                enable_i18n: true,\n                locale_source: "SYSTEM"\n            };\n        }\n    };\n\n    const findCachedI18nValue = currentPayload => {\n        const layerMap = currentPayload?.layer_configs;\n        const values = currentPayload?.values;\n        if (!layerMap || typeof layerMap !== "object") return null;\n\n        for (const metadata of Object.values(layerMap)) {\n            if (!metadata || typeof metadata !== "object") continue;\n\n            const candidates = [];\n            if (metadata.v !== undefined && values && typeof values === "object") {\n                candidates.push(values[String(metadata.v)]);\n            }\n            if (metadata.value && typeof metadata.value === "object") {\n                candidates.push(metadata.value);\n            }\n            candidates.push(metadata);\n\n            for (const candidate of candidates) {\n                if (\n                    candidate &&\n                    hasOwn(candidate, "enable_i18n")\n                ) {\n                    return candidate;\n                }\n            }\n        }\n\n        return null;\n    };\n\n    let layerPatched = patchExistingLayer(payload);\n    if (!layerPatched && !noBootstrap) {\n        insertI18nLayer(payload);\n        layerPatched = true;\n    }\n\n    if (!layerPatched) {\n        return JSON.stringify({\n            ok: false,\n            error: "当前缓存没有语言开关，且未启用补建缓存。",\n            currentCacheKey,\n            allCacheKeys,\n            staleCacheKeys,\n            liveEnableI18n\n        });\n    }\n\n    wrapper = wrapper || {};\n    wrapper.source = wrapper.source || "Bootstrap";\n    wrapper.data = dataWasString ? JSON.stringify(payload) : payload;\n    wrapper.receivedAt = Date.now();\n    wrapper.stableID = context.stableID ?? wrapper.stableID ?? null;\n    wrapper.fullUserHash = wrapper.fullUserHash ?? null;\n\n    const serialized = JSON.stringify(wrapper);\n    localStorage.setItem(currentCacheKey, serialized);\n\n    const savedWrapper = JSON.parse(localStorage.getItem(currentCacheKey));\n    const savedPayload = typeof savedWrapper.data === "string"\n        ? JSON.parse(savedWrapper.data)\n        : savedWrapper.data;\n    const savedValue = findCachedI18nValue(savedPayload);\n\n    const staleCacheResults = [];\n    let staleCachesModified = 0;\n\n    if (patchAllExisting) {\n        for (const staleKey of staleCacheKeys) {\n            try {\n                const staleRaw = localStorage.getItem(staleKey);\n                if (staleRaw === null) {\n                    staleCacheResults.push({\n                        key: staleKey,\n                        status: "missing-during-update"\n                    });\n                    continue;\n                }\n\n                const staleWrapper = JSON.parse(staleRaw);\n                const staleDataWasString = typeof staleWrapper.data === "string";\n                const stalePayload = staleDataWasString\n                    ? JSON.parse(staleWrapper.data)\n                    : staleWrapper.data;\n                const beforeValue = findCachedI18nValue(stalePayload);\n                const wasTrue = beforeValue?.enable_i18n === true;\n\n                let stalePatched = patchExistingLayer(stalePayload);\n                let status = wasTrue ? "already-true" : "patched";\n\n                if (!stalePatched && !noBootstrap) {\n                    insertI18nLayer(stalePayload);\n                    stalePatched = true;\n                    status = "layer-inserted";\n                }\n\n                if (!stalePatched) {\n                    staleCacheResults.push({\n                        key: staleKey,\n                        status: "layer-missing-bootstrap-disabled"\n                    });\n                    continue;\n                }\n\n                if (!wasTrue || status === "layer-inserted") {\n                    staleWrapper.data = staleDataWasString\n                        ? JSON.stringify(stalePayload)\n                        : stalePayload;\n                    staleWrapper.receivedAt = Date.now();\n                    localStorage.setItem(staleKey, JSON.stringify(staleWrapper));\n                    staleCachesModified += 1;\n                }\n\n                const afterValue = findCachedI18nValue(stalePayload);\n                staleCacheResults.push({\n                    key: staleKey,\n                    status,\n                    cachedEnableI18n: afterValue?.enable_i18n ?? null\n                });\n            }\n            catch (error) {\n                staleCacheResults.push({\n                    key: staleKey,\n                    status: "error",\n                    error: String(error)\n                });\n            }\n        }\n    }\n\n    const finalCacheKeys = Object.keys(localStorage)\n        .filter(key => key.startsWith(cachePrefix))\n        .sort();\n\n    return JSON.stringify({\n        ok: Boolean(savedValue && savedValue.enable_i18n === true),\n        mode: "write",\n        origin: location.origin,\n        href: location.href,\n        htmlLang: document.documentElement.lang,\n        statsigStatus: client.loadingStatus,\n        currentCacheKey,\n        currentCacheKeyExists: currentCacheValue !== null,\n        seededFrom,\n        liveEnableI18n,\n        cachedEnableI18n: savedValue?.enable_i18n ?? null,\n        cachedLocaleSource: savedValue?.locale_source ?? null,\n        allCacheKeys: finalCacheKeys,\n        staleCacheKeys,\n        patchAllExisting,\n        staleCachesModified: staleCachesModified > 0,\n        staleCacheModifiedCount: staleCachesModified,\n        staleCacheResults\n    });\n})()'
VERIFY_EXPRESSION = '(() => {\n    const key = \'$escapedKey\';\n    const raw = localStorage.getItem(key);\n    if (raw === null) {\n        return JSON.stringify({ ok: false, reason: "cache-key-missing", key });\n    }\n    try {\n        const wrapper = JSON.parse(raw);\n        const payload = typeof wrapper.data === "string"\n            ? JSON.parse(wrapper.data)\n            : wrapper.data;\n        const values = payload?.values;\n        let value = null;\n        for (const metadata of Object.values(payload?.layer_configs || {})) {\n            if (!metadata || typeof metadata !== "object") continue;\n            const candidates = [];\n            if (metadata.v !== undefined && values) {\n                candidates.push(values[String(metadata.v)]);\n            }\n            candidates.push(metadata.value, metadata);\n            value = candidates.find(candidate =>\n                candidate &&\n                Object.prototype.hasOwnProperty.call(candidate, "enable_i18n")\n            ) || null;\n            if (value) break;\n        }\n        return JSON.stringify({\n            ok: Boolean(value && value.enable_i18n === true),\n            key,\n            cachedEnableI18n: value?.enable_i18n ?? null,\n            cachedLocaleSource: value?.locale_source ?? null\n        });\n    }\n    catch (error) {\n        return JSON.stringify({\n            ok: false,\n            reason: "cache-parse-failed",\n            key,\n            error: String(error)\n        });\n    }\n})()'
SNAPSHOT_EXPRESSION = '(async () => {\n    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));\n    const deadline = Date.now() + __READY_TIMEOUT_MS__;\n    const targetLayer = "72216192";\n    const cachePrefix = "statsig.cached.evaluations.";\n\n    const getRoot = () => window.__STATSIG__ || globalThis.__STATSIG__;\n    const getClient = () => {\n        const root = getRoot();\n        if (!root) return null;\n        return root.firstInstance ||\n            (typeof root.instance === "function" ? root.instance() : null);\n    };\n\n    let client = getClient();\n    while (\n        (!client || String(client.loadingStatus || "") !== "Ready") &&\n        Date.now() < deadline\n    ) {\n        await sleep(250);\n        client = getClient();\n    }\n\n    const htmlLang = String(document.documentElement.lang || "");\n    if (!client) {\n        return JSON.stringify({\n            ok: false,\n            error: "ChatGPT 配置服务未能启动。",\n            currentCacheKey: null,\n            currentCacheKeyExists: false,\n            liveEnableI18n: null,\n            allCacheKeys: [],\n            htmlLang,\n            statsigStatus: null\n        });\n    }\n\n    const statsigStatus = String(client.loadingStatus || "");\n    if (statsigStatus !== "Ready") {\n        return JSON.stringify({\n            ok: false,\n            error: "等待 ChatGPT 配置服务超过 60 秒，尚未就绪。",\n            currentCacheKey: null,\n            currentCacheKeyExists: false,\n            liveEnableI18n: null,\n            allCacheKeys: [],\n            htmlLang,\n            statsigStatus\n        });\n    }\n\n    const context = client.getContext();\n    const currentCacheKey = String(\n        client.dataAdapter._getCacheKey(context.user)\n    );\n    const layer = client.getLayer(targetLayer, {\n        disableExposureLog: true\n    });\n    const allCacheKeys = Object.keys(localStorage)\n        .filter(key => key.startsWith(cachePrefix))\n        .sort();\n\n    return JSON.stringify({\n        ok: true,\n        currentCacheKey,\n        currentCacheKeyExists: localStorage.getItem(currentCacheKey) !== null,\n        liveEnableI18n: layer ? layer.get("enable_i18n", null) : null,\n        allCacheKeys,\n        htmlLang,\n        statsigStatus\n    });\n})()'

# UseGoodAI：保留上游 WebSocket 协议；共享截止时间，所有等待每 5 秒显示中文进度。
@contextmanager
def progress(stage):
    print(stage + '……', flush=True)
    started = time.monotonic()
    done = threading.Event()
    def report():
        while not done.wait(5):
            print(f'{stage}，已等待 {int(time.monotonic() - started)} 秒……', flush=True)
    worker = threading.Thread(target=report, daemon=True)
    worker.start()
    try:
        yield
    finally:
        done.set()
        worker.join()


def remaining(deadline):
    seconds = deadline - time.monotonic()
    if seconds <= 0:
        raise TimeoutError('等待 ChatGPT 超时，已停止等待。')
    return seconds


def recv_exact(s, count, deadline):
    data = b""
    while len(data) < count:
        s.settimeout(remaining(deadline))
        chunk = s.recv(count - len(data))
        if not chunk: raise RuntimeError("调试连接意外关闭")
        data += chunk
    return data


class PageChanged(RuntimeError):
    pass


def evaluate(url, expression, timeout):
    u = urlsplit(url)
    if u.scheme != 'ws' or u.hostname not in ('127.0.0.1', 'localhost'):
        raise RuntimeError('拒绝连接非本机调试地址')
    deadline = time.monotonic() + timeout
    with socket.create_connection(('127.0.0.1', u.port), timeout=min(10, remaining(deadline))) as s:
        s.settimeout(remaining(deadline))
        key = base64.b64encode(os.urandom(16)).decode()
        path = u.path + (('?' + u.query) if u.query else '')
        request = (f'GET {path} HTTP/1.1\r\nHost: 127.0.0.1:{u.port}\r\n'
                   f'Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n'
                   'Sec-WebSocket-Version: 13\r\n\r\n')
        s.sendall(request.encode())
        header = b''
        while not header.endswith(b'\r\n\r\n'):
            header += recv_exact(s, 1, deadline)
            if len(header) > 16384: raise RuntimeError('WebSocket 响应过长')
        expected = base64.b64encode(hashlib.sha1((key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        if not header.startswith(b'HTTP/1.1 101') or expected.lower() not in header.decode('latin1').lower():
            raise RuntimeError('WebSocket 握手失败')
        def send(op, payload):
            n=len(payload); mask=os.urandom(4)
            length=bytes([0x80|n]) if n<126 else (bytes([0xfe])+struct.pack('!H',n) if n<65536 else bytes([0xff])+struct.pack('!Q',n))
            frame = bytes([0x80|op])+length+mask+bytes(v^mask[i%4] for i,v in enumerate(payload))
            s.settimeout(remaining(deadline))
            s.sendall(frame)
        msg=json.dumps({'id':1,'method':'Runtime.evaluate','params':{'expression':expression,'awaitPromise':True,'returnByValue':True}}).encode()
        send(1,msg); fragments=b''
        while True:
            a,b=recv_exact(s,2,deadline); n=b&127
            if n==126: n=struct.unpack('!H',recv_exact(s,2,deadline))[0]
            elif n==127: n=struct.unpack('!Q',recv_exact(s,8,deadline))[0]
            if n>16*1024*1024: raise RuntimeError('调试响应过大')
            mask=recv_exact(s,4,deadline) if b&128 else None
            data=recv_exact(s,n,deadline)
            if mask: data=bytes(v^mask[i%4] for i,v in enumerate(data))
            op=a&15
            if op==8: raise RuntimeError('调试连接已关闭')
            if op==9: send(10,data); continue
            if op not in (0,1): continue
            fragments+=data
            if not a&128: continue
            response=json.loads(fragments); fragments=b''
            if response.get('id') != 1: continue
            if 'error' in response:
                message = str(response['error'].get('message', ''))
                if re.search('Execution context was destroyed|Cannot find context with specified id|Inspected target navigated or closed', message):
                    raise PageChanged('ChatGPT 页面正在切换。')
                raise RuntimeError('ChatGPT 调试调用未完成。')
            result=response['result']
            if 'exceptionDetails' in result: raise RuntimeError('ChatGPT 页面脚本未能执行。')
            return json.loads(result['result']['value'])

# UseGoodAI：复用原 chinese.py 的关闭逻辑：SIGTERM 等 5 秒，再 SIGKILL 并复查。
def run(*arguments, timeout=20):
    return subprocess.run(arguments, capture_output=True, text=True, timeout=timeout)

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
        raise RuntimeError("ChatGPT 未能退出，请从应用菜单彻底退出后重试。")

def debug_pids(executable, port, pids=None):
    flag = f"--remote-debugging-port={port}"
    if pids is None:
        pids = running(executable)
    return {
        pid for pid in pids
        if flag in run("/bin/ps", "-ww", "-p", str(pid), "-o", "command=").stdout.split()
    }

def get_target(port, timeout):
    deadline=time.monotonic()+timeout
    # 本机连接不经过用户的 HTTP 代理。
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    while time.monotonic()<deadline:
        try:
            with opener.open(f'http://127.0.0.1:{port}/json/list',timeout=min(2, remaining(deadline))) as response: targets=json.load(response)
            pages=[x for x in targets if x.get('type')=='page' and x.get('url','').startswith('app://') and x.get('webSocketDebuggerUrl')]
            pages.sort(key=lambda x:not x['url'].startswith('app://-/index.html'))
            if pages: return pages[0]
        except (OSError,ValueError): pass
        time.sleep(min(.5, remaining(deadline)))
    raise RuntimeError('未发现 ChatGPT 调试页面。')


# UseGoodAI：只对已确认的页面切换重查页面，不重复执行主动刷新；与 Windows 修复一致。
def call(port, expression, timeout):
    deadline = time.monotonic() + timeout
    while True:
        target = get_target(port, remaining(deadline))
        try:
            return evaluate(target['webSocketDebuggerUrl'], expression, remaining(deadline))
        except PageChanged:
            if expression == 'location.reload(); "reload-requested"':
                raise
            print('ChatGPT 页面正在切换，正在重新连接……', flush=True)
            time.sleep(min(.5, remaining(deadline)))


def confirm_cache(port, key):
    try: call(port, 'location.reload(); "reload-requested"', 5)
    except (OSError,RuntimeError,ValueError): pass
    time.sleep(.75)
    expression=VERIFY_EXPRESSION.replace("$escapedKey", key.replace('\\','\\\\').replace("'", "\\'"))
    for attempt in range(10):
        try:
            result=call(port,expression,15)
            if result.get('ok'): return
        except (OSError,RuntimeError,ValueError): pass
        time.sleep(.5)
    raise RuntimeError('刷新后未能确认语言缓存已保留。')


def main():
    ap=argparse.ArgumentParser(description='为 macOS ChatGPT 写入中文功能开关缓存')
    ap.add_argument('--app', default='/Applications/ChatGPT.app', help='ChatGPT 应用路径')
    ap.add_argument('--port', type=int, default=0, help='本机调试端口（默认随机空闲端口）')
    ap.add_argument('--timeout', type=int, default=60, help='等待应用启动的秒数（默认 60）')
    args=ap.parse_args()
    if sys.platform!='darwin': raise RuntimeError('此工具仅支持 macOS。')
    if not 0<=args.port<=65535 or args.timeout<5: raise RuntimeError('端口或等待时间无效。')
    app=os.path.realpath(os.path.expanduser(args.app))
    exe=os.path.join(app,'Contents/MacOS/ChatGPT')
    if not os.path.isfile(exe): raise RuntimeError('找不到 ChatGPT 应用：'+app)
    info=run('/usr/libexec/PlistBuddy','-c','Print :CFBundleIdentifier',os.path.join(app,'Contents/Info.plist'))
    if info.stdout.strip()!='com.openai.codex': raise RuntimeError('此应用不是支持的官方 ChatGPT 桌面版。')
    rows=process_snapshot()
    original=matching(rows,exe)
    if original.intersection(own_ancestors(rows)):
        raise RuntimeError('请在 ChatGPT 外部的终端运行。')
    with progress('正在关闭 ChatGPT'):
        stop(exe,original)
    if running(exe): raise RuntimeError('ChatGPT 被其他程序重新打开，请退出后再运行。')
    if args.port: port=args.port
    else:
        with socket.socket() as probe:
            probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
    with socket.socket() as probe:
        try: probe.bind(('127.0.0.1',port))
        except OSError: raise RuntimeError('本机调试端口已被占用。')
    print('正在临时打开 ChatGPT 以写入语言缓存，完成后会自动关闭……',flush=True)
    try:
        subprocess.Popen(['/usr/bin/open','-a',app,'--args',f'--remote-debugging-port={port}',f'--remote-allow-origins=http://127.0.0.1:{port}'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        with progress('正在等待 ChatGPT 页面'):
            get_target(port,args.timeout)
        expression=EXPRESSION.replace('__INSPECT_ONLY__','false').replace('__NO_BOOTSTRAP__','false').replace('__PATCH_ALL_EXISTING__','true').replace('__READY_TIMEOUT_MS__','60000')
        with progress('正在等待 ChatGPT 配置服务加载'):
            result=call(port,expression,90)
        if not result.get('ok'): raise RuntimeError(result.get('error','语言缓存写入失败。'))
        source={'current-cache':'已有缓存','context-values':'当前配置','minimal-bootstrap':'补建缓存'}.get(result.get('seededFrom'),'当前缓存')
        print('缓存来源：'+source,flush=True)
        print('语言缓存已写入。',flush=True)
        with progress('正在刷新页面，检查语言缓存'):
            confirm_cache(port,result['currentCacheKey'])
        print('刷新检查通过，语言缓存已保留。',flush=True)
        for check in range(1,3):
            print(f'正在等待第 {check}/2 次复查（3 秒）……',flush=True)
            time.sleep(3)
            with progress(f'第 {check}/2 次复查：正在等待 ChatGPT 加载'):
                snapshot=call(port,SNAPSHOT_EXPRESSION.replace('__READY_TIMEOUT_MS__','60000'),90)
            if not snapshot.get('ok'): raise RuntimeError(f'第 {check}/2 次复查未完成，ChatGPT 配置服务尚未就绪。')
            if not snapshot.get('currentCacheKeyExists'): raise RuntimeError(f'第 {check}/2 次复查未找到语言缓存。')
            print(f'第 {check}/2 次复查通过，语言缓存已保留。',flush=True)
    finally:
        # UseGoodAI：沿用项目 SIGTERM 正常退出使缓存落盘；成功、失败或中断均收尾，不自动重开。
        prior_mask=signal.pthread_sigmask(signal.SIG_BLOCK,{signal.SIGINT,signal.SIGHUP,signal.SIGTERM})
        try:
            with progress('正在保存语言缓存并关闭 ChatGPT'):
                wait_until(lambda: debug_pids(exe,port),3)
                stop(exe,running(exe))
        finally: signal.pthread_sigmask(signal.SIG_SETMASK,prior_mask)
    print('[成功] 中文缓存已写入，ChatGPT 已关闭。请自己重新打开 ChatGPT。',flush=True)


def interrupted(_signum, _frame):
    raise KeyboardInterrupt()


if __name__=='__main__':
    signal.signal(signal.SIGHUP,interrupted)
    signal.signal(signal.SIGTERM,interrupted)
    try: main()
    except (Exception, KeyboardInterrupt) as e:
        reason = str(e)
        if isinstance(e, KeyboardInterrupt): reason = '运行已中断。'
        elif isinstance(e, TimeoutError): reason = '等待 ChatGPT 超时，已停止等待。'
        elif not re.search('[一-鿿]', reason): reason = '运行未完成，请退出 ChatGPT 后重试。'
        print('[失败] '+reason,file=sys.stderr,flush=True)
        sys.exit(1)
USEGOODAI_CODEX_CHINESE_PYTHON
