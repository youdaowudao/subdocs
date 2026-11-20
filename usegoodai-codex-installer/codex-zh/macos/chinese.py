#!/usr/bin/env python3
"""Seed the Codex Statsig i18n cache via a temporary local CDP connection."""
import argparse, base64, hashlib, json, os, socket, struct, subprocess, sys, time, urllib.request
from urllib.parse import urlsplit
from contextlib import contextmanager
import re, signal, threading

# UseGoodAI：构建时嵌入 Windows current-key 原版页面脚本及原版刷新校验，运行时不下载核心。
EXPRESSION = ""
VERIFY_EXPRESSION = ""
SNAPSHOT_EXPRESSION = ""

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


# UseGoodAI：主程序退出后，复用同一 TERM/KILL 顺序收尾已确认属于该应用的后台进程。
# 以当前用户、真实可执行文件及父子关系限定范围，不按 codex 名称结束终端程序。
def stop_desktop(executable, pids):
    prefix = os.path.dirname(os.path.dirname(str(executable))) + os.sep
    owned = {}

    def remaining_owned():
        rows = process_snapshot()
        parents = set(pids) | set(owned)
        changed = True
        while changed:
            changed = False
            for pid, (parent, uid, state, path) in rows.items():
                if uid != os.getuid() or state.startswith('Z') or not path.startswith(prefix):
                    continue
                # Crashpad detaches from its parent. This exact bundled diagnostic
                # executable belongs to the App; it is not an interactive CLI.
                diagnostic = os.path.basename(path) == 'browser_crashpad_handler'
                if pid not in parents and parent not in parents and not diagnostic:
                    continue
                if pid in owned and owned[pid] != path:
                    continue
                owned[pid] = path
                if pid not in parents:
                    parents.add(pid)
                    changed = True
        return {pid: path for pid, path in owned.items()
                if pid in rows and rows[pid][1] == os.getuid()
                and not rows[pid][2].startswith('Z') and rows[pid][3] == path}

    remaining_owned()
    # UseGoodAI：Mac 压力测试中停页面等 2 秒仍出现缓存校验错误；先请求 App 正常退出，
    # 复用原 TERM/KILL 清理兜底。正常退出失败时只报错，不确认保存成功。
    quit_failed = False
    if running(executable).intersection(pids):
        app_path = os.path.dirname(os.path.dirname(os.path.dirname(str(executable))))
        try:
            result = run('/usr/bin/osascript', '-e',
                         'on run argv\ntell application (item 1 of argv) to quit\nend run', app_path)
        except (OSError, subprocess.TimeoutExpired):
            result = None
        quit_failed = (result is None or result.returncode != 0 or
                       not wait_until(lambda: not running(executable).intersection(pids), 5))
    active = remaining_owned()
    renderers = {pid: path for pid, path in active.items()
                 if '--type=renderer' in run('/bin/ps', '-ww', '-p', str(pid), '-o', 'command=').stdout.split()}
    for path in set(renderers.values()):
        signal_matching(path, {pid for pid, owner in renderers.items() if owner == path}, signal.SIGKILL)
    if renderers:
        time.sleep(2)
    stop(executable, pids)
    if not wait_until(lambda: not remaining_owned(), 2):
        leftovers = remaining_owned()
        for path in sorted(set(leftovers.values())):
            stop(path, {pid for pid, owner in leftovers.items() if owner == path})
    if remaining_owned():
        raise RuntimeError('ChatGPT 的后台进程尚未退出，请退出后重试。')
    if quit_failed:
        raise RuntimeError('ChatGPT 未能正常退出，本次无法确认语言缓存已保存。')

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
        stop_desktop(exe,original)
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
        # UseGoodAI：页面进程先落盘，再沿用项目关闭逻辑；成功、失败或中断均收尾，不自动重开。
        prior_mask=signal.pthread_sigmask(signal.SIG_BLOCK,{signal.SIGINT,signal.SIGHUP,signal.SIGTERM})
        try:
            with progress('正在保存语言缓存并关闭 ChatGPT'):
                wait_until(lambda: debug_pids(exe,port),3)
                stop_desktop(exe,running(exe))
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
