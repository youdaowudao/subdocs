#!/usr/bin/env python3
"""生图工具进度汇报与卡住自停：在 GitHub 的 Windows / Apple 芯片 Mac 上用官方 Codex 实测。

1. 安装官方 Codex（Windows 用 npm 版，与 Windows App 同一内核；Mac 用官方 App 内置后端）。
2. 把候选生图工具装进真实的 ~/.codex，写入临时假 Key；全新安装后先跑一次 doctor，核对放行规则一项。
3. 本机冒充 api.usegoodai.com：自签证书加入系统信任，hosts 指向 127.0.0.1，按提示词里的场景控制返回：
   正常（35 秒后返回约 6 MB）、慢速（约 2.5 MB，每秒约 60 KB）、中断（返回 1 MB 后不再发送）、不返回（一直不回应）。
4. 先在 Codex 外直接运行一次“正常”，按到达时间记录每条进度行，确认是边跑边输出而不是结束时一次性输出。
5. 替身模型扮演 gpt-6.1-sol（代码模式），逐字使用已安装 Skill 里的 Code Mode 脚本运行每个场景，
   记录模型在命令结束前收到了哪些进度行、最终结果，以及服务器看到连接断开的时间。
Windows 另有一组把 PowerShell 7 从 PATH 拿掉，让 Codex 改用系统自带的 Windows PowerShell 5.1。
不使用任何真实密钥；结论写入 report.json 与 Actions 摘要，任何一项不符合预期即以非零退出。
"""

import argparse
import base64
import datetime
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import socket
import ssl
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('mac_repro', HERE / 'image-vpn-proxy-mac.py')
mac = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mac)
spec = importlib.util.spec_from_file_location('win_repro', HERE / 'image-vpn-proxy-windows.py')
win = importlib.util.module_from_spec(spec)
spec.loader.exec_module(win)

API_HOST = 'api.usegoodai.com'
TINY_PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/T6R2JQAAAABJRU5ErkJggg==')
SCENARIOS = {
    # 场景：(返回前等待秒数, 图片填充字节数, 每秒发送字节数, 发送多少后停住；None 表示发完)
    '正常': (35, 4_500_000, 1_000_000, None),
    '慢速': (5, 1_800_000, 60_000, None),
    '中断': (5, 4_500_000, 1_000_000, 1_100_000),
    '不返回': (None, 0, 0, None),
}
PROGRESS = re.compile(r'^\[生图 (\d+):(\d\d)\] (.*)$')
SERVER_LOG = []


def image_body(padding):
    content = TINY_PNG + bytes(padding)
    return json.dumps({'data': [{'b64_json': base64.b64encode(content).decode()}]}).encode()


def received_text(item):
    """模型收到的一次工具输出；Code Mode 每个 text(...) 是一项，按行拼接。"""
    value = item.get('output')
    if isinstance(value, list):
        return '\n'.join(part.get('text', '') for part in value if isinstance(part, dict))
    return mac.output_text(item)


class QuietServer(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        # 工具主动断开连接（中断、不返回、连接复用结束）是本测试预期的情况，不打印堆栈。
        if not isinstance(sys.exc_info()[1], (ConnectionError, ssl.SSLError, TimeoutError)):
            super().handle_error(request, client_address)


def make_certificates(work):
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

    now = datetime.datetime.now(datetime.timezone.utc)
    ca_key = ec.generate_private_key(ec.SECP256R1())
    ca_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'UseGoodAI progress test CA')])
    ca = (x509.CertificateBuilder().subject_name(ca_name).issuer_name(ca_name).public_key(ca_key.public_key())
          .serial_number(x509.random_serial_number()).not_valid_before(now - datetime.timedelta(days=1))
          .not_valid_after(now + datetime.timedelta(days=30))
          .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
          .add_extension(x509.SubjectKeyIdentifier.from_public_key(ca_key.public_key()), critical=False)
          .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False,
                                       data_encipherment=False, key_agreement=False, key_cert_sign=True, crl_sign=True,
                                       encipher_only=False, decipher_only=False), critical=True)
          .sign(ca_key, hashes.SHA256()))
    key = ec.generate_private_key(ec.SECP256R1())
    cert = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, API_HOST)]))
            .issuer_name(ca_name).public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(days=1)).not_valid_after(now + datetime.timedelta(days=30))
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(API_HOST)]), critical=False)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
            .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False,
                                         data_encipherment=False, key_agreement=False, key_cert_sign=False,
                                         crl_sign=False, encipher_only=False, decipher_only=False), critical=True)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()), critical=False)
            .sign(ca_key, hashes.SHA256()))
    paths = {name: work / f'{name}.pem' for name in ['ca', 'cert', 'key']}
    paths['ca'].write_bytes(ca.public_bytes(serialization.Encoding.PEM))
    paths['cert'].write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    paths['key'].write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                               serialization.NoEncryption()))
    return paths


def impersonate_api(paths, report):
    """系统信任测试 CA，api.usegoodai.com 指向本机。"""
    if sys.platform == 'win32':
        steps = [['certutil', '-addstore', '-f', 'Root', str(paths['ca'])]]
        with open(win.HOSTS, 'a', encoding='ascii') as hosts:
            hosts.write(f'\n127.0.0.1 {API_HOST}\n')
        steps.append(['ipconfig', '/flushdns'])
    else:
        steps = [['/usr/bin/sudo', '/usr/bin/security', 'add-trusted-cert', '-d', '-r', 'trustRoot',
                  '-k', '/Library/Keychains/System.keychain', str(paths['ca'])],
                 ['/bin/sh', '-c', f'echo "127.0.0.1 {API_HOST}" | /usr/bin/sudo /usr/bin/tee -a /etc/hosts'],
                 ['/usr/bin/sudo', '/usr/bin/dscacheutil', '-flushcache'],
                 ['/usr/bin/sudo', '/usr/bin/killall', '-HUP', 'mDNSResponder']]
    results = []
    for step in steps:
        result = subprocess.run(step, capture_output=True, text=True, errors='replace')
        results.append({'command': ' '.join(step[:3]), 'code': result.returncode,
                        'output': (result.stdout + result.stderr).strip()[-300:]})
    time.sleep(2)
    report['impersonation'] = {'steps': results, 'resolved': socket.gethostbyname(API_HOST)}


def serve_api(paths):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *args):
            pass

        def do_GET(self):
            body = json.dumps({'object': 'list', 'data': [{'id': 'gpt-image-2.6-flare'}]}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def wait_for_close(self, entry, limit):
            """不再发送数据，等客户端自己断开，记下断开的时间。"""
            self.connection.settimeout(1)
            deadline = time.time() + limit
            while time.time() < deadline:
                try:
                    if not self.connection.recv(1):
                        break
                except socket.timeout:
                    continue
                except (OSError, ssl.SSLError):
                    break
            entry['closed_at'] = time.time()
            self.close_connection = True

        def do_POST(self):
            payload = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))) or b'{}')
            scenario = next((name for name in SCENARIOS if name in payload.get('prompt', '')), '正常')
            delay, padding, rate, stop_after = SCENARIOS[scenario]
            entry = {'scenario': scenario, 'received_at': time.time()}
            SERVER_LOG.append(entry)
            if delay is None:
                self.wait_for_close(entry, 400)
                return
            time.sleep(delay)
            body = image_body(padding)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            entry.update(headers_at=time.time(), size=len(body))
            sent = 0
            chunk = max(1, rate // 10)
            try:
                while sent < len(body):
                    if stop_after is not None and sent >= stop_after:
                        entry['stalled_at'] = time.time()
                        self.wait_for_close(entry, 400)
                        entry['sent'] = sent
                        return
                    piece = body[sent:sent + chunk]
                    self.wfile.write(piece)
                    self.wfile.flush()
                    sent += len(piece)
                    time.sleep(0.1)
            except OSError:
                entry['closed_at'] = time.time()
            entry.update(sent=sent, finished_at=time.time())

    # macOS 只允许普通用户在所有地址上监听 1024 以下端口。
    server = QuietServer(('127.0.0.1' if sys.platform == 'win32' else '0.0.0.0', 443), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(paths['cert'], paths['key'])
    server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


class SkillCodeModeModel:
    """Responses API 替身：第一次逐字发出 Skill 的 Code Mode 脚本，之后按 Skill 对同一 cell 调用 wait。"""

    def __init__(self):
        self.lock = threading.Lock()
        self.reset('', '')

    def reset(self, script, command):
        with self.lock:
            self.script = script
            self.command = command
            self.outputs = []
            self.received = []
            self.tools_seen = []
            self.started = time.time()

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
                if 'exec' in tools:
                    return {'type': 'custom_tool_call', 'name': 'exec', 'input': self.script}
                if 'shell_command' in tools:
                    return mac.StandInModel.function('shell_command', {'command': self.command, 'timeout_ms': 720000})
                raise RuntimeError(f'没有可用的命令工具：{tools}')
            new = outputs[len(self.outputs):]
            for item in new:
                text = received_text(item)
                self.outputs.append(text)
                self.received.append({'seconds': round(time.time() - self.started, 1), 'text': text})
            latest = self.outputs[-1] if self.outputs else ''
            if len(self.outputs) >= 40:
                return None
            cell = re.search(r'Script running with cell ID (\S+)', latest)
            if cell:
                return mac.StandInModel.function('wait', {'cell_id': cell.group(1), 'yield_time_ms': 30000})
            return None


MODEL = SkillCodeModeModel()


def skill_script(skill_text, command, workdir):
    section = skill_text.split('### Code Mode 结果与进度转发', 1)[1]
    snippet = section.split('```javascript', 1)[1].split('```', 1)[0].strip('\n')
    first, rest = snippet.split('\n', 1)
    if not first.startswith('// @exec:'):
        raise SystemExit('Skill 的 Code Mode 脚本首行不是 @exec')
    return (f'{first}\nconst cmd = {json.dumps(command, ensure_ascii=False)};\n'
            f'const workdir = {json.dumps(str(workdir), ensure_ascii=False)};\n{rest}\n')


def progress_lines(text):
    return [line.strip() for line in text.splitlines() if PROGRESS.match(line.strip())]


def final_result(outputs):
    """Skill 脚本最后 text 的 {exit_code, output}，以及其中工具输出的结果 JSON。"""
    for text in reversed(outputs):
        for match in re.finditer(r'\{"exit_code".*\}', text):
            try:
                wrapper = json.loads(match.group(0))
            except ValueError:
                continue
            tool = None
            for line in reversed(str(wrapper.get('output', '')).splitlines()):
                try:
                    tool = json.loads(line)
                    break
                except ValueError:
                    continue
            return wrapper, tool
    return None, None


def run_direct(tool, output_dir):
    """Codex 外直接运行，按到达时间记录每条 stderr 进度行。"""
    command = [str(tool), 'generate', '--model', 'gpt-image-2.6-flare', '--prompt', '正常 进度直连测试',
               '--n', '1', '--size', '2048x2048', '--quality', 'high', '--output-name', '进度直连测试',
               '--output-dir', str(output_dir)]
    started = time.time()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    arrivals = []
    for raw in iter(process.stderr.readline, b''):
        arrivals.append({'arrived': round(time.time() - started, 1), 'line': raw.decode('utf-8', 'replace').rstrip()})
    stdout = process.stdout.read().decode('utf-8', 'replace')
    process.wait()
    stamped = []
    for item in arrivals:
        match = PROGRESS.match(item['line'])
        if match:
            stamped.append(int(match.group(1)) * 60 + int(match.group(2)))
    streamed = (len(stamped) >= 5 and all(abs(a['arrived'] - s) <= 2.5 for a, s in
                                           zip([a for a in arrivals if PROGRESS.match(a['line'])], stamped)))
    heartbeat = sum('等待中转站生成，已等' in a['line'] for a in arrivals)
    return {'exit': process.returncode, 'stdout': stdout.strip()[-400:], 'lines': arrivals,
            'streamed_in_real_time': streamed, 'waiting_heartbeats': heartbeat,
            'ok': process.returncode == 0 and streamed and heartbeat >= 1 and '"ok":true' in stdout.replace(' ', '')}


def run_codex(name, backend, command, script, codex_home, workspace, port, report_dir, env_change=None):
    (codex_home / 'config.toml').write_text(
        'model = "gpt-6.1-sol"\nmodel_provider = "repro"\n'
        'approval_policy = "on-request"\nsandbox_mode = "workspace-write"\n'
        + ('windows.sandbox = "unelevated"\n' if sys.platform == 'win32' else '') +
        'check_for_update_on_startup = false\n\n'
        '[model_providers.repro]\nname = "repro"\n'
        f'base_url = "http://127.0.0.1:{port}/v1"\nwire_api = "responses"\nrequires_openai_auth = false\n',
        encoding='utf-8')
    MODEL.reset(script, command)
    env = {key: value for key, value in os.environ.items() if key != 'CODEX_HOME'}
    if env_change:
        env = env_change(env)
    started = time.time()
    try:
        result = subprocess.run([str(backend), 'exec', '--json', '--skip-git-repo-check', '画一张图'], cwd=workspace,
                                env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=900)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, code = error.stdout or '', (error.stderr or '') + '\nTIMEOUT', -1
        stdout = stdout if isinstance(stdout, str) else stdout.decode('utf-8', 'replace')
    (report_dir / f'{name}.exec.jsonl').write_text(stdout, encoding='utf-8')
    (report_dir / f'{name}.stderr.txt').write_text(stderr if isinstance(stderr, str) else stderr.decode(), encoding='utf-8')
    (report_dir / f'{name}.model-received.json').write_text(json.dumps(MODEL.received, ensure_ascii=False, indent=2),
                                                            encoding='utf-8')
    executed = []
    for line in stdout.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        item = event.get('item') or {}
        if item.get('type') == 'command_execution' and event.get('type') == 'item.completed':
            executed.append(item.get('command'))
    wrapper, tool_result = final_result(MODEL.outputs)
    before_end = MODEL.received[:-1]
    return {'codex_exit': code, 'seconds': round(time.time() - started, 1), 'tools_offered': MODEL.tools_seen[:12],
            'executed_commands': executed, 'model_turns': len(MODEL.received),
            'progress_before_end': [line for item in before_end for line in progress_lines(item['text'])],
            'progress_at_end': progress_lines(MODEL.received[-1]['text']) if MODEL.received else [],
            'exit_code': (wrapper or {}).get('exit_code'), 'tool_result': tool_result}


def expect(name, result, server_entry):
    """每个场景的预期；返回不符合的说明列表。"""
    problems = []
    tool = result.get('tool_result') or {}
    seen = result['progress_before_end'] + result['progress_at_end']
    if result['codex_exit'] != 0:
        problems.append(f"Codex 退出码 {result['codex_exit']}")
    if not any('请求已发出' in line for line in result['progress_before_end']):
        problems.append('命令结束前模型没有收到“请求已发出”进度行')
    if name in ('正常', '慢速'):
        if result['exit_code'] != 0 or tool.get('ok') is not True or not tool.get('output_file'):
            problems.append(f'没有成功出图：{tool}')
        for part in ['中转站已返回 HTTP 200', '接收完成', '已保存：']:
            if not any(part in line for line in seen):
                problems.append(f'缺少进度“{part}”')
    if name == '慢速' and not any(re.search(r'接收中 .*近 \d+ 秒 \d+ KB/s', line) for line in seen):
        problems.append('慢速接收没有报告速度')
    if name == '中断':
        if not re.match(r'^接收中断：60 秒没有新数据，已收 1\.0 MB/[\d.]+ MB。$', str(tool.get('error', ''))) \
                or tool.get('request_sent') is not True:
            problems.append(f'中断结论不对：{tool}')
        stalled, closed = server_entry.get('stalled_at'), server_entry.get('closed_at')
        if not (stalled and closed and 58 <= closed - stalled <= 75):
            problems.append(f'停止时间不对：停住后 {None if not (stalled and closed) else round(closed - stalled, 1)} 秒断开')
    if name == '不返回':
        if tool.get('error') != '请求已发出，已等 3 分钟，中转站没有开始返回。' or tool.get('request_sent') is not True:
            problems.append(f'不返回结论不对：{tool}')
        received, closed = server_entry.get('received_at'), server_entry.get('closed_at')
        if not (received and closed and 178 <= closed - received <= 195):
            problems.append(f'停止时间不对：收到请求后 {None if not (received and closed) else round(closed - received, 1)} 秒断开')
    if any('扣费' in line for line in seen) or '扣费' in json.dumps(tool, ensure_ascii=False):
        problems.append('输出提到扣费')
    return problems


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tool', required=True, help='候选生图工具程序')
    parser.add_argument('--powershell51', action='store_true', help='Windows：把 PowerShell 7 从 PATH 拿掉')
    args = parser.parse_args()
    windows = sys.platform == 'win32'
    work = Path(os.environ.get('RUNNER_TEMP', os.environ.get('TEMP', '/tmp'))) / 'image-progress'
    report_dir = work / 'report'
    report_dir.mkdir(parents=True, exist_ok=True)
    home = Path.home()
    codex_home = home / '.codex'
    if codex_home.exists() and any(codex_home.iterdir()):
        raise SystemExit(f'测试机已有 {codex_home}，不覆盖')
    codex_home.mkdir(parents=True, exist_ok=True)
    desktop_images = home / 'Desktop' / 'images'
    workspace = home / 'progress-work'
    workspace.mkdir(exist_ok=True)

    report = {'platform': sys.platform}
    if windows:
        report['system'] = subprocess.run(['cmd', '/c', 'ver'], capture_output=True, text=True).stdout.strip()
        backend = win.install_codex(report)
        tool, skill_command = win.install_tool(Path(args.tool), codex_home, work, report)
    else:
        report['system'] = subprocess.run(['/usr/bin/sw_vers'], capture_output=True, text=True).stdout
        backend = mac.download_official_backend(work, report)
        user, original_shell = mac.login_shell()
        report['original_login_shell'] = original_shell
        if original_shell != '/bin/zsh':
            mac.set_login_shell(user, '/bin/zsh')
        tool = mac.install_tool(Path(args.tool), codex_home, work, report)
        skill_command = str(tool)
    report['backend_version'] = subprocess.run([str(backend), '--version'], capture_output=True, text=True).stdout.strip()
    skill_text = (codex_home / 'skills' / 'usegoodai-image-generation' / 'SKILL.md').read_text(encoding='utf-8')

    # 全新安装后的诊断：放行规则一项不应报“不一致”。
    doctor = subprocess.run([str(tool), 'doctor'], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=120)
    checks = {}
    try:
        checks = {check['name']: check for check in json.loads(doctor.stdout)['checks']}
    except (ValueError, KeyError):
        pass
    rule = checks.get('Codex 放行规则', {})
    report['doctor_after_fresh_install'] = {'rule': rule, 'skill': checks.get('Skill', {})}
    failures = []
    if not rule.get('ok') or not checks.get('Skill', {}).get('ok'):
        failures.append(f'全新安装后 doctor：Skill={checks.get("Skill")} 规则={rule}')

    paths = make_certificates(work)
    impersonate_api(paths, report)
    api = serve_api(paths)

    direct = run_direct(tool, work / 'direct-images')
    report['direct_outside_codex'] = direct
    if not direct['ok']:
        failures.append(f"Codex 外直接运行：退出 {direct['exit']}，实时输出 {direct['streamed_in_real_time']}，等待心跳 {direct['waiting_heartbeats']}")

    env_change = None
    if args.powershell51:
        def env_change(env):
            parts = [part for part in env.get('PATH', '').split(os.pathsep) if 'powershell\\7' not in part.lower()]
            return dict(env, PATH=os.pathsep.join(parts))
    model_server = mac.serve(MODEL)
    port = model_server.server_address[1]
    scenarios = {}
    for name in SCENARIOS:
        command = (f"{skill_command} generate --model 'gpt-image-2.6-flare' --prompt '{name} 进度测试' --n '1' "
                   f"--size '2048x2048' --quality 'high' --output-name '进度测试-{name}' --output-dir '{desktop_images}'")
        before = len(SERVER_LOG)
        result = run_codex(name, backend, command, skill_script(skill_text, command, workspace), codex_home,
                           workspace, port, report_dir, env_change)
        entry = next((item for item in SERVER_LOG[before:] if item['scenario'] == name), {})
        result['server'] = {key: round(value - entry['received_at'], 1) if key.endswith('_at') else value
                            for key, value in entry.items()}
        result['problems'] = expect(name, result, entry)
        scenarios[name] = result
        failures += [f'{name}：{problem}' for problem in result['problems']]
        print(json.dumps({name: {k: result[k] for k in ['codex_exit', 'seconds', 'exit_code', 'tool_result', 'problems']}},
                         ensure_ascii=False), flush=True)
    model_server.shutdown()
    api.shutdown()
    report['shell'] = sorted({cmd.split('"')[1] if cmd and cmd.startswith('"') else (cmd or '').split(' ')[0]
                              for result in scenarios.values() for cmd in result['executed_commands']})
    if args.powershell51 and not any('powershell.exe' in shell.lower() for shell in report['shell']):
        failures.append(f"没有改用 Windows PowerShell 5.1：{report['shell']}")
    report['scenarios'] = scenarios
    report['failures'] = failures
    (report_dir / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

    lines = [f"## 生图进度实测（{'Windows' + (' PowerShell 5.1' if args.powershell51 else '') if windows else 'Mac'}）",
             f"- Codex：`{report['backend_version']}`；命令所用 shell：`{report['shell']}`",
             f"- 全新安装后 doctor 放行规则：{'通过' if rule.get('ok') else '失败'}（{rule.get('detail', '')[:120]}）",
             f"- Codex 外直接运行：{'通过' if direct['ok'] else '失败'}，进度行按时到达：{direct['streamed_in_real_time']}"]
    for name, result in scenarios.items():
        tool_result = result['tool_result'] or {}
        verdict = '通过' if not result['problems'] else '失败：' + '；'.join(result['problems'])
        outcome = tool_result.get('output_file') or tool_result.get('error')
        lines.append(f"- {name}：{verdict}。用时 {result['seconds']} 秒；结束前模型收到 {len(result['progress_before_end'])} 条进度；"
                     f"结果 `{str(outcome)[:120]}`；服务器 `{result['server']}`")
        if result['progress_before_end']:
            lines.append(f"  - 结束前最后一条：`{result['progress_before_end'][-1]}`")
    summary = '\n'.join(lines) + '\n'
    print(summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as handle:
            handle.write(summary)
    if failures:
        raise SystemExit('不符合预期：\n' + '\n'.join(failures))


if __name__ == '__main__':
    main()
