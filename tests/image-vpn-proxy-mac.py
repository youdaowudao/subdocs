#!/usr/bin/env python3
"""复现：Mac 上官方 Codex App 自带的后端按放行规则运行生图工具时，命令是否仍留在沙箱里。

在 GitHub 的 Apple 芯片 macOS 运行器上：
1. 从官方 appcast 下载当前 ChatGPT/Codex App，使用 App 内置的 Codex 后端（与客户 App 同一内核）。
2. 把客户拿到的已发布 V0.9.3 darwin-arm64 生图工具装进真实的 ~/.codex，写入临时假 Key（不是真实 Key）。
3. 本地替身模型扮演 gpt-6.1-sol（代码模式），逐字按已安装 Skill 的写法运行 `doctor`；
   每个场景都是新启动的 Codex 进程，相当于“完全退出并重新打开”。
4. 记录工具是否在沙箱内（CODEX_SANDBOX）、能否连上 api.usegoodai.com（假 Key 返回 401 即说明网络通）、能否写桌面。

只做复现与取证，不修改工具；脚本本身只在测试机器上运行。
本机核对替身流程时可用 --backend/--tool 指定已有程序并跳过 App 下载与登录 shell 切换。
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import socket
import socketserver
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import xml.etree.ElementTree as ET
import zipfile

REPO = Path(__file__).resolve().parents[1]
RELEASE_TOOL = REPO / 'docs/public/install/usegoodai-imagines-tool/releases/v0.9.3/usegoodai-imagines-tool-v0.9.3-darwin-arm64'
FEED = 'https://persistent.oaistatic.com/codex-app-prod/appcast.xml'
FAKE_KEY = 'sk-reproonlynotarealkey000000'
MAX_STEPS = 12


def run(command, **kwargs):
    kwargs.setdefault('capture_output', True)
    kwargs.setdefault('text', True)
    return subprocess.run(command, **kwargs)


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


class StandInModel:
    """Responses API 替身：第一次回复一条工具调用，之后轮询直到命令结束，再结束回合。"""

    def __init__(self):
        self.lock = threading.Lock()
        self.reset('', 'code')

    def reset(self, command, mode):
        with self.lock:
            self.command = command
            self.mode = mode
            self.outputs = []
            self.tools_seen = []

    def first_call(self, tools):
        command = json.dumps(self.command, ensure_ascii=False)
        if 'exec' in tools:
            source = (
                '// @exec: {"yield_time_ms": 30000}\n'
                f'let s = await tools.exec_command({{cmd: {command}, yield_time_ms: 30000}});\n'
                'let out = s.output;\n'
                'while (s.exit_code === undefined && s.session_id !== undefined) {\n'
                '  s = await tools.write_stdin({session_id: s.session_id, yield_time_ms: 30000});\n'
                '  out += s.output;\n'
                '}\n'
                'text("REPRO_RESULT " + JSON.stringify({exit_code: s.exit_code, output: out}));\n'
            )
            return {'type': 'custom_tool_call', 'name': 'exec', 'input': source}
        if 'exec_command' in tools:
            return self.function('exec_command', {'cmd': self.command, 'yield_time_ms': 30000})
        if 'shell_command' in tools:
            return self.function('shell_command', {'command': self.command, 'timeout_ms': 240000})
        raise RuntimeError(f'没有可用的命令工具：{tools}')

    @staticmethod
    def function(name, arguments):
        return {'type': 'function_call', 'name': name, 'arguments': json.dumps(arguments, ensure_ascii=False)}

    def next_item(self, request):
        tools = [tool.get('name') for tool in (request.get('tools') or [])]
        inputs = [item for item in request.get('input', []) if isinstance(item, dict)]
        for item in inputs:
            if item.get('type') == 'additional_tools':
                for namespace in item.get('tools', []):
                    tools += [tool.get('name') for tool in namespace.get('tools', [])]
        outputs = [item for item in inputs if str(item.get('type', '')).endswith('call_output')]
        with self.lock:
            self.tools_seen = sorted(set(filter(None, tools)))
            if not outputs:
                return self.first_call(tools)
            latest = output_text(outputs[-1])
            self.outputs.append(latest)
            if len(outputs) >= MAX_STEPS:
                return None
            cell = re.search(r'Script running with cell ID (\S+)', latest)
            if cell and 'REPRO_RESULT' not in latest:
                return self.function('wait', {'cell_id': cell.group(1), 'yield_time_ms': 30000})
            session = re.search(r'session ID (\d+)', latest)
            if session and 'Process exited with code' not in latest and 'REPRO_RESULT' not in latest:
                return self.function('write_stdin', {'session_id': int(session.group(1)), 'yield_time_ms': 30000})
            return None


def output_text(item):
    value = item.get('output')
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return ''.join(part.get('text', '') for part in value if isinstance(part, dict))
    if isinstance(value, dict):
        return value.get('content') if isinstance(value.get('content'), str) else json.dumps(value, ensure_ascii=False)
    return json.dumps(value, ensure_ascii=False)


def serve(model):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            body = b'{"object":"list","data":[],"models":[]}'
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            request = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))) or b'{}')
            call = model.next_item(request)
            if call is None:
                item = {'type': 'message', 'role': 'assistant', 'id': 'msg_1',
                        'content': [{'type': 'output_text', 'text': '完成'}]}
            else:
                step = len(model.outputs) + 1
                item = dict(call, id=f'item_{step}', call_id=f'call_{step}', status='completed')
            usage = {'input_tokens': 1, 'output_tokens': 1, 'total_tokens': 2}
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.end_headers()
            for event in [
                {'type': 'response.created', 'response': {'id': 'resp_1'}},
                {'type': 'response.output_item.done', 'output_index': 0, 'item': item},
                {'type': 'response.completed', 'response': {'id': 'resp_1', 'usage': usage}},
            ]:
                self.wfile.write(f"event: {event['type']}\ndata: {json.dumps(event, ensure_ascii=False)}\n\n".encode())
            self.wfile.flush()

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def download_official_backend(work, report):
    appcast = work / 'appcast.xml'
    result = run(['/usr/bin/curl', '-fsSL', '--retry', '2', '-o', str(appcast), FEED], timeout=120)
    if result.returncode:
        raise SystemExit(f'无法下载 appcast：{result.stderr}')
    item = ET.parse(appcast).find('./channel/item')
    url = item.find('enclosure').attrib['url']
    if not url.startswith('https://persistent.oaistatic.com/codex-app-prod/'):
        raise SystemExit(f'官方安装包地址异常：{url}')
    package = work / 'official.zip'
    result = run(['/usr/bin/curl', '-fSL', '--retry', '2', '--connect-timeout', '15', '--max-time', '900',
                  '-o', str(package), url], timeout=960)
    if result.returncode:
        raise SystemExit(f'无法下载官方 App：{result.stderr[-2000:]}')
    with zipfile.ZipFile(package) as archive:
        app_name = next(name.split('/')[0] for name in archive.namelist()
                        if name.endswith('.app/Contents/Info.plist') and name.count('/') == 2)
    unpacked = work / 'app'
    result = run(['/usr/bin/ditto', '-x', '-k', str(package), str(unpacked)], timeout=600)
    if result.returncode:
        raise SystemExit(f'无法解压官方 App：{result.stderr}')
    app = unpacked / app_name
    backend = app / 'Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex'
    if not backend.is_file():
        found = [str(path) for path in app.rglob('codex') if path.is_file() and os.access(path, os.X_OK)]
        raise SystemExit(f'官方 App 中的 Codex 后端位置变化：{found}')
    info = run(['/usr/bin/defaults', 'read', str(app / 'Contents/Info'), 'CFBundleShortVersionString'])
    report['official_app'] = {'url': url, 'sha256': digest(package), 'app': app_name,
                              'app_version': info.stdout.strip(), 'backend': str(backend)}
    package.unlink()
    return backend


def login_shell():
    user = os.environ.get('USER') or run(['/usr/bin/id', '-un']).stdout.strip()
    result = run(['/usr/bin/dscl', '.', '-read', f'/Users/{user}', 'UserShell'])
    return user, result.stdout.strip().split(':', 1)[-1].strip()


def set_login_shell(user, shell):
    result = run(['/usr/bin/sudo', '/usr/bin/dscl', '.', '-create', f'/Users/{user}', 'UserShell', shell])
    if result.returncode:
        raise SystemExit(f'无法切换登录 shell 到 {shell}：{result.stderr}')


def install_tool(tool_source, codex_home, work, report):
    staged = work / 'download' / 'usegoodai-imagines-tool'
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(tool_source, staged)
    staged.chmod(0o755)
    env = {key: value for key, value in os.environ.items() if key != 'CODEX_HOME'}
    result = run([str(staged), 'install'], input='\n', env=env, timeout=120)
    (work / 'report' / 'install.txt').write_text(result.stdout + '\n--- stderr ---\n' + result.stderr)
    if result.returncode:
        raise SystemExit(f'生图工具安装失败：{result.stdout[-2000:]}{result.stderr[-2000:]}')
    tool_dir = codex_home / 'tools' / 'usegoodai-imagines-tool'
    key = tool_dir / 'api-key'
    key.write_text(FAKE_KEY + '\n')
    key.chmod(0o600)
    tool = tool_dir / 'usegoodai-imagines-tool'
    skill = (codex_home / 'skills' / 'usegoodai-image-generation' / 'SKILL.md').read_text()
    if f'{tool} generate --model' not in skill:
        raise SystemExit('已安装 Skill 中的工具命令与安装位置不一致')
    rules = codex_home / 'rules' / 'usegoodai-imagines-tool.rules'
    report['tool'] = {'source': str(tool_source), 'sha256': digest(tool_source), 'installed': str(tool),
                      'rules': rules.read_text(), 'other_rules': sorted(p.name for p in rules.parent.glob('*.rules') if p != rules)}
    return tool


def parse_doctor(text):
    for candidate in re.findall(r'REPRO_RESULT (\{.*\})', text):
        try:
            text = json.loads(candidate)['output'] + '\n' + text
            break
        except (ValueError, KeyError):
            pass
    match = re.search(r'\{"checks":.*?"version":"[^"]*"\}', text)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except ValueError:
        return None


def summarize(doctor):
    if doctor is None:
        return {'tool_ran': False}
    checks = {check['name']: check for check in doctor['checks']}
    network = checks.get('连接 api.usegoodai.com', {})
    desktop = checks.get('输出目录', {})
    sandbox = checks.get('运行环境')
    return {
        'tool_ran': True,
        'in_sandbox': bool(sandbox),
        'sandbox_detail': sandbox['detail'] if sandbox else '',
        'network_reached': '网络已连通' in network.get('detail', '') or network.get('ok', False),
        'network_detail': network.get('detail', ''),
        'desktop_writable': desktop.get('ok', False),
        'desktop_detail': desktop.get('detail', ''),
        'rule_check': checks.get('Codex 放行规则', {}).get('ok'),
    }


def run_scenario(name, backend, model, mode, config, command, codex_home, workspace, port, report_dir):
    (codex_home / 'config.toml').write_text(
        f'model = "{model}"\nmodel_provider = "repro"\n{config}'
        'check_for_update_on_startup = false\n\n'
        '[model_providers.repro]\nname = "repro"\n'
        f'base_url = "http://127.0.0.1:{port}/v1"\nwire_api = "responses"\nrequires_openai_auth = false\n')
    MODEL.reset(command, mode)
    env = {key: value for key, value in os.environ.items() if key != 'CODEX_HOME'}
    try:
        result = run([str(backend), 'exec', '--json', '--skip-git-repo-check', '画一张白底红苹果'],
                     cwd=workspace, env=env, stdin=subprocess.DEVNULL, timeout=420)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, code = error.stdout or '', (error.stderr or '') + '\nTIMEOUT', -1
    (report_dir / f'{name}.exec.jsonl').write_text(stdout if isinstance(stdout, str) else stdout.decode())
    (report_dir / f'{name}.stderr.txt').write_text(stderr if isinstance(stderr, str) else stderr.decode())
    outputs = '\n'.join(MODEL.outputs)
    (report_dir / f'{name}.tool-output.txt').write_text(outputs)
    executed = []
    for line in (stdout if isinstance(stdout, str) else '').splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        item = event.get('item') or {}
        if item.get('type') == 'command_execution' and event.get('type') == 'item.completed':
            executed.append(item.get('command'))
    result = summarize(parse_doctor(outputs))
    result.update({'scenario': name, 'model': model, 'codex_exit': code, 'tools_offered': MODEL.tools_seen[:12],
                   'executed_commands': executed})
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return result


MODEL = StandInModel()
API_HOST = 'api.usegoodai.com'
BLACKHOLE = '10.255.255.1'
PROXY_LOG = []


def start_connect_proxy(real_ip, port=7890):
    """模拟 VPN 客户端的本地代理（如 127.0.0.1:7890）：转发 HTTPS 的 CONNECT 和普通 HTTP 请求；
    api.usegoodai.com 用开启“直连不通”之前解析到的真实地址转发。
    Codex 自己也走系统代理，连本机替身模型的普通 HTTP 请求也会经过这里。"""

    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            client = self.request
            data = b''
            while b'\r\n\r\n' not in data:
                chunk = client.recv(4096)
                if not chunk:
                    return
                data += chunk
            head, rest = data.split(b'\r\n\r\n', 1)
            first_line, _, header_block = head.partition(b'\r\n')
            method, target, version = first_line.decode('latin1').split(' ', 2)
            if method == 'CONNECT':
                host, port = target.rsplit(':', 1)
                port = int(port)
                prefix, reply = b'', b'HTTP/1.1 200 Connection Established\r\n\r\n'
            else:
                url = urllib.parse.urlsplit(target)
                host, port = url.hostname, url.port or 80
                path = (url.path or '/') + (f'?{url.query}' if url.query else '')
                headers = [line for line in header_block.split(b'\r\n')
                           if line and not line.lower().startswith(b'proxy-connection')]
                prefix = f'{method} {path} {version}\r\n'.encode('latin1') + b'\r\n'.join(headers) + b'\r\n\r\n'
                reply = b''
            PROXY_LOG.append(f'{method} {host}')
            try:
                upstream = socket.create_connection((real_ip if host == API_HOST else host, port), timeout=20)
                upstream.settimeout(None)
            except OSError:
                client.sendall(b'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n')
                return
            if reply:
                client.sendall(reply)
            if prefix or rest:
                upstream.sendall(prefix + rest)

            def pipe(source, target):
                try:
                    while True:
                        chunk = source.recv(65536)
                        if not chunk:
                            break
                        target.sendall(chunk)
                except OSError:
                    pass
                finally:
                    for sock in (source, target):
                        try:
                            sock.shutdown(socket.SHUT_RDWR)
                        except OSError:
                            pass

            forward = threading.Thread(target=pipe, args=(client, upstream), daemon=True)
            forward.start()
            pipe(upstream, client)
            forward.join(5)

    class Server(socketserver.ThreadingTCPServer):
        daemon_threads = True
        allow_reuse_address = True

    server = Server(('127.0.0.1', port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def default_interface():
    output = run(['/sbin/route', '-n', 'get', 'default']).stdout
    match = re.search(r'interface:\s*(\S+)', output)
    return match.group(1) if match else 'en0'


def direct_curl(as_root=False):
    command = ['/usr/bin/curl', '-sS', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '20',
               f'https://{API_HOST}/v1/models']
    started = time.time()
    result = run((['/usr/bin/sudo'] if as_root else []) + command)
    return {'result': (result.stdout + result.stderr).strip(), 'seconds': round(time.time() - started, 1)}


def simulate_tun(report, work):
    """开着 TUN 模式 VPN 的 Mac：当前用户（runner）的直连在物理网卡上被防火墙丢弃，只能经 TUN 虚拟网卡；
    VPN 客户端 sing-box 以 root 运行，经 TUN 接管全部流量再从物理网卡发出。没有设置系统代理。"""
    user = run(['/usr/bin/id', '-un']).stdout.strip()
    addresses = sorted({info[4][0] for info in socket.getaddrinfo(API_HOST, 443, socket.AF_INET, socket.SOCK_STREAM)})
    interface = default_interface()
    rules = work / 'pf-repro.conf'
    rules.write_text(''.join(f'block drop out quick on {interface} proto tcp from any to {address} port 443 user {user}\n'
                             for address in addresses))
    loaded = run(['/usr/bin/sudo', '/sbin/pfctl', '-f', str(rules)])
    enabled = run(['/usr/bin/sudo', '/sbin/pfctl', '-E'])
    info = {'user': user, 'addresses': addresses, 'interface': interface,
            'pf': (loaded.stdout + loaded.stderr + enabled.stdout + enabled.stderr).strip()[-600:],
            'direct_before_tun': direct_curl(), 'root_direct_before_tun': direct_curl(as_root=True)}
    installed = run(['brew', 'install', 'sing-box'], timeout=900)
    binary = shutil.which('sing-box') or '/opt/homebrew/bin/sing-box'
    info['sing_box'] = run([binary, 'version']).stdout.strip() or installed.stderr[-600:]
    config = work / 'sing-box.json'
    config.write_text(json.dumps({
        'log': {'level': 'warn'},
        'inbounds': [{'type': 'tun', 'tag': 'tun-in', 'address': ['172.19.0.1/30'], 'auto_route': True,
                      'stack': 'system'}],
        'outbounds': [{'type': 'direct', 'tag': 'direct'}],
        'route': {'auto_detect_interface': True, 'final': 'direct'},
    }, indent=2))
    log = open(work / 'report' / 'sing-box.log', 'w')
    subprocess.Popen(['/usr/bin/sudo', binary, 'run', '-c', str(config)], stdout=log, stderr=subprocess.STDOUT)
    time.sleep(8)
    info['utun'] = [line for line in run(['/sbin/ifconfig']).stdout.splitlines() if '172.19.0.1' in line]
    info['scutil_proxy'] = run(['/usr/sbin/scutil', '--proxy']).stdout
    info['direct_with_tun'] = direct_curl()
    report['tun_simulation'] = info
    print(json.dumps(info, ensure_ascii=False, indent=2), flush=True)


def simulate_vpn(report):
    """开着 VPN 的 Mac：系统代理指向本地代理；api.usegoodai.com 直连不通（发往不可达地址，等到超时）。"""
    real_ip = socket.gethostbyname(API_HOST)
    report['_proxy_server'] = start_connect_proxy(real_ip)
    services = [line.lstrip('*').strip() for line in
                run(['/usr/sbin/networksetup', '-listallnetworkservices']).stdout.splitlines()[1:] if line.strip()]
    for service in services:
        for option in ['-setwebproxy', '-setsecurewebproxy']:
            run(['/usr/bin/sudo', '/usr/sbin/networksetup', option, service, '127.0.0.1', '7890'])
        run(['/usr/bin/sudo', '/usr/sbin/networksetup', '-setproxybypassdomains', service,
             'localhost', '127.0.0.1', '*.local', '169.254/16'])
    run(['/usr/bin/sudo', '/bin/sh', '-c', f'echo "{BLACKHOLE} {API_HOST}" >> /etc/hosts'])
    run(['/usr/bin/sudo', '/usr/bin/dscacheutil', '-flushcache'])
    run(['/usr/bin/sudo', '/usr/bin/killall', '-HUP', 'mDNSResponder'])
    time.sleep(2)
    report['vpn_simulation'] = {
        'real_ip': real_ip, 'services': services,
        'scutil_proxy': run(['/usr/sbin/scutil', '--proxy']).stdout,
        'resolved_after': socket.gethostbyname(API_HOST),
        'env_proxy': {key: os.environ.get(key) for key in ['HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'ALL_PROXY']},
    }

    # 走系统代理的程序（Python urllib 在 macOS 上读取系统代理，和 ChatGPT 一样）能否连上
    started = time.time()
    request = urllib.request.Request(f'https://{API_HOST}/v1/models', headers={'Authorization': f'Bearer {FAKE_KEY}'})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            outcome = f'HTTP {response.status}'
    except urllib.error.HTTPError as error:
        outcome = f'HTTP {error.code}（网络已连通）'
    except Exception as error:  # noqa: BLE001 - 记录任何失败
        outcome = f'失败：{error!r}'
    report['vpn_simulation']['system_proxy_client'] = {
        'proxies_seen': urllib.request.getproxies(), 'result': outcome, 'seconds': round(time.time() - started, 1)}

    # 不经过系统代理的直连（curl 默认不读系统代理）是否超时
    started = time.time()
    direct = run(['/usr/bin/curl', '-sS', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '20',
                  f'https://{API_HOST}/v1/models'])
    report['vpn_simulation']['direct_connection'] = {
        'result': (direct.stdout + direct.stderr).strip(), 'seconds': round(time.time() - started, 1)}
    print(json.dumps(report['vpn_simulation'], ensure_ascii=False, indent=2), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--backend', help='本机核对替身流程用：已有的 Codex 程序')
    parser.add_argument('--tool', help='本机核对替身流程用：已有的生图工具程序')
    parser.add_argument('--vpn', action='store_true', help='模拟开着 VPN（系统代理）且直连不通的 Mac')
    parser.add_argument('--tun', action='store_true', help='模拟开着 TUN 模式 VPN 且直连不通的 Mac')
    args = parser.parse_args()
    local = bool(args.backend)
    if not local and not (sys.platform == 'darwin' and platform.machine() == 'arm64'):
        raise SystemExit('需要真实的 Apple 芯片 macOS')

    work = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'image-rule-repro'
    report_dir = work / 'report'
    report_dir.mkdir(parents=True, exist_ok=True)
    home = Path.home()
    codex_home = home / '.codex'
    if codex_home.exists() and any(codex_home.iterdir()) and not local:
        raise SystemExit(f'测试机已有 {codex_home}，不覆盖')
    codex_home.mkdir(parents=True, exist_ok=True)
    desktop = home / 'Desktop'
    desktop.mkdir(exist_ok=True)
    workspace = home / 'repro-work'
    workspace.mkdir(exist_ok=True)

    report = {}
    if local:
        backend = Path(args.backend)
    else:
        report['system'] = run(['/usr/bin/sw_vers']).stdout
        backend = download_official_backend(work, report)
    report['backend_version'] = run([str(backend), '--version']).stdout.strip()
    tool = install_tool(Path(args.tool) if args.tool else RELEASE_TOOL, codex_home, work, report)
    command = f"{tool} doctor --output-dir '{desktop}'"
    report['command'] = command

    if args.vpn:
        simulate_vpn(report)
    if args.tun:
        simulate_tun(report, work)
    started = time.time()
    baseline = run([str(tool), 'doctor', '--output-dir', str(desktop)], timeout=180)
    report['baseline_outside_codex'] = dict(summarize(parse_doctor(baseline.stdout)),
                                            seconds=round(time.time() - started, 1))
    policy = run([str(backend), 'execpolicy', 'check', '--rules',
                  str(codex_home / 'rules' / 'usegoodai-imagines-tool.rules'), str(tool), 'doctor'])
    report['execpolicy_check'] = (policy.stdout + policy.stderr).strip()

    server = serve(MODEL)
    port = server.server_address[1]
    configs = {
        'workspace-write': 'approval_policy = "on-request"\nsandbox_mode = "workspace-write"\n',
        'read-only': 'approval_policy = "on-request"\nsandbox_mode = "read-only"\n',
    }
    if local:
        shells = [None]
    else:
        user, original_shell = login_shell()
        report['original_login_shell'] = original_shell
        shells = ['/bin/zsh', '/bin/bash']
    results = []
    if args.vpn or args.tun:
        # 开着 VPN：按客户的 zsh、请求批准（workspace-write）、gpt-6.1-sol 代码模式，连续两次新启动 Codex。
        if not local:
            set_login_shell(user, '/bin/zsh')
        prefix = 'vpn' if args.vpn else 'tun'
        for attempt in ['第1次启动', '第2次重新启动']:
            started = time.time()
            result = run_scenario(f'{prefix}-zsh-workspace-write-code-{attempt}', backend, 'gpt-6.1-sol', 'code',
                                  configs['workspace-write'], command, codex_home, workspace, port, report_dir)
            results.append(dict(result, seconds=round(time.time() - started, 1)))
        if args.vpn:
            # VPN 软件退出但系统代理设置还在：Codex 自己也会断，所以在 Codex 外直接运行诊断，
            # 看它报告网络问题和当前代理，而不是“规则没生效、去重启”。
            proxy_server = report.pop('_proxy_server')
            proxy_server.shutdown()
            proxy_server.server_close()
            started = time.time()
            quit_run = run([str(tool), 'doctor', '--output-dir', str(desktop)], timeout=180)
            report['vpn_quit_outside_codex'] = dict(summarize(parse_doctor(quit_run.stdout)),
                                                    seconds=round(time.time() - started, 1))
            # VPN 改用 PAC（自动代理）模式，然后完全关闭代理：看诊断给出的指导。
            for service in report['vpn_simulation']['services']:
                for option in ['-setwebproxystate', '-setsecurewebproxystate']:
                    run(['/usr/bin/sudo', '/usr/sbin/networksetup', option, service, 'off'])
                run(['/usr/bin/sudo', '/usr/sbin/networksetup', '-setautoproxyurl', service, 'http://127.0.0.1:7890/pac'])
            pac_run = run([str(tool), 'doctor', '--output-dir', str(desktop)], timeout=180)
            report['pac_outside_codex'] = summarize(parse_doctor(pac_run.stdout))
            for service in report['vpn_simulation']['services']:
                run(['/usr/bin/sudo', '/usr/sbin/networksetup', '-setautoproxystate', service, 'off'])
            none_run = run([str(tool), 'doctor', '--output-dir', str(desktop)], timeout=180)
            report['no_proxy_outside_codex'] = summarize(parse_doctor(none_run.stdout))
        shells = []
        report['proxy_log'] = PROXY_LOG
    for shell in shells:
        if shell:
            set_login_shell(user, shell)
        shell_name = Path(shell).name if shell else 'current'
        for config_name, config in configs.items():
            for model, mode in [('gpt-6.1-sol', 'code'), ('repro-plain-model', 'direct')]:
                name = f'{shell_name}-{config_name}-{mode}'
                results.append(dict(run_scenario(name, backend, model, mode, config, command,
                                                 codex_home, workspace, port, report_dir),
                                    login_shell=shell or 'current', sandbox_mode=config_name))
        # 对照组：给工具路径加引号，已知不匹配放行规则；用来确认这套检测能识别“仍在沙箱内”，
        # 并记录沙箱内联网失败在这台机器上的实际表现（立即失败还是超时）。
        name = f'{shell_name}-workspace-write-code-对照不匹配'
        results.append(dict(run_scenario(name, backend, 'gpt-6.1-sol', 'code', configs['workspace-write'],
                                         f"'{tool}' doctor --output-dir '{desktop}'",
                                         codex_home, workspace, port, report_dir),
                            login_shell=shell or 'current', sandbox_mode='workspace-write'))
    server.shutdown()
    report['scenarios'] = results
    (report_dir / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))

    lines = [
        '## Mac 生图放行规则复现',
        f"- Codex 后端：`{report['backend_version']}`；App：`{report.get('official_app', {}).get('app_version', '本机核对')}`",
        f"- 沙箱外直接运行（基线）：网络 `{report['baseline_outside_codex'].get('network_detail', '')[:80]}`",
        f"- `execpolicy check`：`{report['execpolicy_check'][:160]}`",
    ]
    if args.vpn:
        vpn = report['vpn_simulation']
        lines += [
            f"- 模拟 VPN：系统代理 127.0.0.1:7890；直连解析为 `{vpn['resolved_after']}`",
            f"- 走系统代理的程序（同 ChatGPT）：`{vpn['system_proxy_client']['result']}`，{vpn['system_proxy_client']['seconds']} 秒",
            f"- 不走系统代理的直连：`{vpn['direct_connection']['result'][:100]}`，{vpn['direct_connection']['seconds']} 秒",
            f"- 生图工具在 Codex 外直接运行：{report['baseline_outside_codex'].get('seconds')} 秒，"
            f"`{report['baseline_outside_codex'].get('network_detail', '')[:160]}`",
        ]
        for key, label in [('vpn_quit_outside_codex', 'VPN 软件退出（系统代理还在）后'), ('pac_outside_codex', 'VPN 用 PAC 模式时'),
                           ('no_proxy_outside_codex', '没有任何代理时')]:
            if key in report:
                lines.append(f"- {label}直接运行诊断：`{report[key].get('network_detail', '')[:400]}`")
    if args.tun:
        tun = report['tun_simulation']
        lines += [
            f"- 模拟 TUN：sing-box `{tun.get('sing_box', '')[:60]}`，虚拟网卡 `{tun.get('utun')}`；没有设置系统代理",
            f"- 开 TUN 前：当前用户直连 `{tun['direct_before_tun']['result'][:80]}`，root 直连 `{tun['root_direct_before_tun']['result'][:80]}`",
            f"- 开 TUN 后：当前用户直连 `{tun['direct_with_tun']['result'][:80]}`，{tun['direct_with_tun']['seconds']} 秒",
            f"- 生图工具在 Codex 外直接运行：{report['baseline_outside_codex'].get('seconds')} 秒，"
            f"`{report['baseline_outside_codex'].get('network_detail', '')[:160]}`",
        ]
    if args.vpn or args.tun:
        for item in results:
            lines.append(f"- {item['scenario']}：在沙箱内 `{item.get('in_sandbox')}`，用时 {item.get('seconds')} 秒，"
                         f"诊断说 `{item.get('network_detail', '')[:200]}`")
    lines += [
        '',
        '| 场景 | 工具运行 | 在沙箱内 | 连上 api.usegoodai.com | 能写桌面 | 实际命令 |',
        '|---|---|---|---|---|---|',
    ]
    for item in results:
        lines.append('| {} | {} | {} | {} | {} | `{}` |'.format(
            item['scenario'], item.get('tool_ran'), item.get('in_sandbox'), item.get('network_reached'),
            item.get('desktop_writable'), (item['executed_commands'][:1] or [''])[0][:120]))
    summary = '\n'.join(lines) + '\n'
    print(summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write(summary)
    if not any(item.get('tool_ran') for item in results):
        raise SystemExit('替身流程没有让 Codex 运行工具，复现环境本身有问题')


if __name__ == '__main__':
    main()
