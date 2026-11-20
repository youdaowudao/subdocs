#!/usr/bin/env python3
"""Optional real macOS Chinese UI verification. Only synthetic credentials; no new release gate."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import runpy
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET
import zipfile

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / 'usegoodai-codex-installer/codex-zh/macos'
CORE = runpy.run_path(str(SOURCE / 'chinese.py'))
ROOT = Path(os.environ['RUNNER_TEMP']) / 'chinese-macos'
REPORT = ROOT / 'report'
REPORT.mkdir(parents=True, exist_ok=True)
report = {'failures': [], 'runs': []}


def save():
    (REPORT / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))


def require(condition, text):
    if not condition:
        raise AssertionError(text)


def execute(args, timeout=90, check=True, **kwargs):
    result = subprocess.run(list(map(str, args)), text=True, capture_output=True, timeout=timeout, **kwargs)
    if check:
        require(result.returncode == 0, f'{args[0]} failed: {result.stderr[-1500:]}')
    return result


def digest(file):
    return hashlib.sha256(Path(file).read_bytes()).hexdigest()


def download(url, path):
    execute(['/usr/bin/curl', '-fsSL', '--retry', '2', '--connect-timeout', '15', '--max-time', '540', url, '-o', path], timeout=600)


def install():
    download('https://persistent.oaistatic.com/codex-app-prod/appcast.xml', ROOT / 'feed.xml')
    release = ET.parse(ROOT / 'feed.xml').find('./channel/item')
    url = release.find('enclosure').attrib['url']
    require(url.startswith('https://persistent.oaistatic.com/codex-app-prod/'), 'Unexpected package source')
    download(url, ROOT / 'official.zip')
    with zipfile.ZipFile(ROOT / 'official.zip') as archive:
        name = next(x.split('/')[0] for x in archive.namelist() if x.endswith('.app/Contents/Info.plist') and x.count('/') == 2)
    require(name == 'ChatGPT.app', 'Review changed official application name')
    execute(['/usr/bin/ditto', '-x', '-k', ROOT / 'official.zip', ROOT / 'unpacked'], timeout=180)
    app = Path('/Applications') / name
    require(not app.exists(), 'Refusing to replace an existing application')
    execute(['sudo', '/usr/bin/ditto', ROOT / 'unpacked' / name, app], timeout=180)
    signature = execute(['/usr/bin/codesign', '--verify', '--deep', '--strict', app])
    identity = execute(['/usr/bin/codesign', '-dv', '--verbose=4', app]).stderr
    require('TeamIdentifier=2DC432GLL2' in identity, 'Unexpected official signing team')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(info['CFBundleIdentifier'] == 'com.openai.codex', 'Unexpected bundle identifier')
    report['official'] = {'url': url, 'packageSha256': digest(ROOT / 'official.zip'), 'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'], 'signature': identity}
    return app


def flush_dns():
    execute(['sudo', '/usr/bin/dscacheutil', '-flushcache'])
    execute(['sudo', '/usr/bin/killall', '-HUP', 'mDNSResponder'], check=False)


def set_network(mode):
    if mode == 'online':
        return
    windows = (REPO / 'tests/codex-chinese-desktop.ps1').read_text(encoding='utf-8-sig')
    hosts = re.findall("'([^']+)'", windows.split('$blockedHosts = @(', 1)[1].split('\n)', 1)[0])
    ip = '192.0.2.1' if mode == 'blackhole' else '127.0.0.1'
    additions = '\n# Chinese UI isolated test\n' + ''.join(f'{ip} {host}\n' for host in hosts)
    execute(['sudo', '/usr/bin/tee', '-a', '/etc/hosts'], input=additions)
    flush_dns()
    report['networkSetup'] = {'hosts': hosts, 'address': ip}
    # Resolve via the native system resolver used by the application.
    report['resolvedStatsig'] = execute(['/usr/bin/dscacheutil', '-q', 'host', '-a', 'name', 'ab.chatgpt.com']).stdout
    require(ip in report['resolvedStatsig'], 'Network condition not installed')


def stop():
    CORE['stop'](str(executable), CORE['running'](str(executable)))


def open_app(debug=False):
    args = ['/usr/bin/open', '-a', app]
    if debug:
        args += ['--args', '--remote-debugging-port=9333', '--remote-allow-origins=http://127.0.0.1:9333']
    execute(args)
    require(CORE['wait_until'](lambda: CORE['running'](str(executable)), 15), 'Application did not start')


def listeners():
    result = execute(['/usr/sbin/lsof', '-nP', '-iTCP', '-sTCP:LISTEN'], check=False)
    return [line for line in result.stdout.splitlines() if 'ChatGPT' in line]


def app_processes():
    return [line for line in execute(['/bin/ps', '-ww', '-axo', 'pid=,command=']).stdout.splitlines() if str(app) + '/Contents/' in line]


def save_databases():
    # Keep the real failed WAL if one occurs; no extra I/O between repair and
    # ordinary reopen. All reads/copies run only after the scenario has ended.
    support = Path.home() / 'Library/Application Support'
    report['databaseCopies'] = []
    for base in support.iterdir():
        if not base.is_dir() or not any(name in base.name.lower() for name in ('codex', 'chatgpt')):
            continue
        for directory in base.rglob('leveldb'):
            if 'Local Storage' not in directory.parts:
                continue
            destination = REPORT / f"final-db{len(report['databaseCopies'])+1}"
            shutil.copytree(directory, destination, ignore=shutil.ignore_patterns('LOCK'))
            report['databaseCopies'].append(str(directory))


def capture(label):
    pids = CORE['running'](str(executable))
    require(len(pids) == 1, 'Expected one normal main application process')
    window = execute([ROOT / 'window-reader', 'window', str(next(iter(pids)))]).stdout.strip()
    image = REPORT / (label + '.png')
    execute(['/usr/sbin/screencapture', '-x', '-l', window, image])
    text = execute([ROOT / 'window-reader', 'ocr', image]).stdout
    (REPORT / (label + '.txt')).write_text(text)
    return {'window': window, 'cjk': len(re.findall('[一-鿿]', text)), 'text': text}


def snapshot(label):
    stop()
    open_app(True)
    try:
        windows = (REPO / 'tests/codex-chinese-desktop.ps1').read_text(encoding='utf-8-sig')
        js = re.search(r"\$snapshotJs = @'\n(.*?)\n'@", windows, re.S)[1]
        result = CORE['call'](9333, js, 100)
        (REPORT / (label + '.json')).write_text(json.dumps(result, ensure_ascii=False, indent=2))
        return result
    finally:
        stop()


def onboarding():
    open_app(True)
    steps = []
    try:
        deadline = time.monotonic() + 150
        while time.monotonic() < deadline:
            state = CORE['call'](9333, (REPO / 'tests/chinese-onboarding.js').read_text(), 15)
            steps.append(state)
            report['onboarding'] = steps
            save()
            if state.get('done'):
                return
            time.sleep(1)
        raise AssertionError('API-key fixture did not reach the actual main conversation screen')
    finally:
        stop()


def observe_old_cdp(done, evidence):
    """Passively capture only this disposable app's CDP replies, without changing old bytes."""
    capture = None
    try:
        while not done.wait(.1):
            found = re.search(r'--remote-debugging-port=(\d+)', '\n'.join(app_processes()))
            if not found:
                continue
            port = int(found[1])
            evidence['port'] = port
            with (REPORT / 'old-capture-stderr.txt').open('wb') as errors:
                capture = subprocess.Popen(['sudo', '/usr/sbin/tcpdump', '-U', '-i', 'lo0', '-s', '0', '-w', str(REPORT / 'old-cdp.pcap'),
                                            f'tcp and src host 127.0.0.1 and src port {port}'], stdout=subprocess.DEVNULL, stderr=errors)
                while not done.wait(.1) and capture.poll() is None:
                    pass
                if capture.poll() is None:
                    execute(['sudo', '/bin/kill', '-INT', capture.pid], check=False)
                capture.wait(10)
            break
        pcap = REPORT / 'old-cdp.pcap'
        if pcap.exists():
            execute(['sudo', '/bin/chmod', 'a+r', pcap])
            # Incoming expressions are excluded by src-port filtering. This text
            # must be in an actual response, not the old code sent by the client.
            evidence['statsigTimeoutCaptured'] = b'Statsig did not become ready or has an unsupported cache adapter.' in pcap.read_bytes()
            evidence['pcapSha256'] = digest(pcap)
    except Exception as error:
        evidence['error'] = str(error)
    finally:
        if capture and capture.poll() is None:
            execute(['sudo', '/bin/kill', '-TERM', capture.pid], check=False)
            capture.wait(10)


def run_tool(label, expect_success=True, previous=False, interrupt=False):
    (REPORT / (label + '-before-processes.txt')).write_text('\n'.join(app_processes()))
    # Exactly the published one-line shell entry: local HTTP serves the immutable candidate bytes.
    command = f'/usr/bin/curl -fsSL http://127.0.0.1:{server.server_port}/chinese.sh | /bin/bash'
    child = subprocess.Popen(['/bin/bash', '-o', 'pipefail', '-c', command], env=script_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True, bufsize=1)
    started = time.monotonic()
    received = []
    def read():
        for line in child.stdout:
            received.append((time.monotonic() - started, line))
    thread = threading.Thread(target=read, daemon=True)
    thread.start()
    old_done = threading.Event()
    old_evidence = {}
    if args.old:
        observer = threading.Thread(target=observe_old_cdp, args=(old_done, old_evidence), daemon=True)
        observer.start()
    sent_interrupt = False
    while child.poll() is None:
        if time.monotonic() - started > 240:
            os.killpg(child.pid, signal.SIGTERM)
            raise AssertionError('Tool exceeded four-minute test cap')
        if interrupt and not sent_interrupt:
            commands = app_processes()
            if any('--remote-debugging-port=' in line for line in commands):
                os.killpg(child.pid, signal.SIGINT)
                sent_interrupt = True
        time.sleep(.2)
    thread.join(5)
    elapsed = time.monotonic() - started
    if args.old:
        old_done.set()
        observer.join(20)
        require(not observer.is_alive(), 'Old comparison capture did not stop')
        report['oldFailureEvidence'] = old_evidence
    output = ''.join(line for _, line in received)
    (REPORT / (label + '-output.txt')).write_text(output)
    timeline = [0] + [at for at, _ in received] + [elapsed]
    closing = [at for at, line in received if line.strip() == '正在保存语言缓存并关闭 ChatGPT……']
    time.sleep(2)  # Match Windows' brief OS process-reaping observation window.
    row = {'label': label, 'seconds': round(elapsed, 2), 'maxOutputGap': round(max(b - a for a, b in zip(timeline, timeline[1:])), 2), 'exit': child.returncode, 'success': '[成功]' in output or '已启用语言开关并设置简体中文' in output, 'previousCache': '缓存来源：已有缓存' in output, 'interruptSent': sent_interrupt, 'closingSeconds': round(elapsed-closing[0], 2) if closing else None, 'remainingProcesses': app_processes(), 'listeners': listeners()}
    report['runs'].append(row)
    save()
    if expect_success:
        require(child.returncode == 0 and row['success'], label + ' did not succeed')
        require(not row['remainingProcesses'] and not row['listeners'], label + ' left processes or listeners')
        require(row['maxOutputGap'] < 12, label + ' had silent waiting')
        require(elapsed < 180, label + ' exceeded three minutes')
        if previous:
            require(row['previousCache'], label + ' lost the prior cache')
        # Observe any late startup before the test explicitly opens the normal application.
        time.sleep(3)
        require(not app_processes(), label + ' reopened the application late')
        open_app()
        time.sleep(50)
        row['normalReopen'] = capture(label + '-normal')
        require(row['normalReopen']['cjk'] >= 5, label + ' normal window was not Chinese')
        if args.auth == 'apikey':
            require('新聊天' in row['normalReopen']['text'], label + ' did not show the Chinese new-chat control')
        else:
            require(re.search(r'登录\s*ChatGPT|继续登录', row['normalReopen']['text']), label + ' did not show Chinese sign-in controls')
        save()
    elif interrupt:
        require(sent_interrupt and not row['success'], 'Interrupt did not reach the running repair')
        time.sleep(5)
        require(not app_processes() and not listeners(), 'Interrupted repair left the application running')
    else:
        require(child.returncode != 0 and not row['success'], 'Old 1.0.2 did not reproduce the expected failure')
        require(old_evidence.get('statsigTimeoutCaptured') is True, 'Old failure was not proven to be the Statsig eight-second timeout')
        row['oldReopened'] = bool(app_processes())
        save()
    return row


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--network', choices=['refused', 'blackhole', 'online'], required=True)
    parser.add_argument('--auth', choices=['apikey', 'login'], required=True)
    parser.add_argument('--old', action='store_true')
    args = parser.parse_args()
    report.update(network=args.network, auth=args.auth, old=args.old, sha=os.environ.get('GITHUB_SHA'), system=platform.platform(), machine=platform.machine(), python=sys.version)
    require(sys.platform == 'darwin' and platform.machine() == 'arm64', 'A real Apple Silicon Mac is required')
    hosts = Path('/etc/hosts').read_bytes()
    prior_home = execute(['/bin/launchctl', 'getenv', 'CODEX_HOME'], check=False).stdout.strip()
    app = install()
    executable = app / 'Contents/MacOS/ChatGPT'
    files = [executable, app / 'Contents/Resources/app.asar']
    original_hashes = {str(p): digest(p) for p in files}
    config_home = ROOT / '用户 中文 空格'
    config_home.mkdir()
    config = '# preserve existing configuration\n'
    if args.auth == 'apikey':
        config += 'model_provider = "OpenAI"\nmodel = "gpt-6.1-sol"\n[model_providers.OpenAI]\nname = "OpenAI"\nbase_url = "http://127.0.0.1:9/v1"\nwire_api = "responses"\nrequires_openai_auth = true\n'
        (config_home / 'auth.json').write_text('{"OPENAI_API_KEY":"sk-ci-fake-key-not-real"}\n')
    config += '[desktop]\nlocaleOverride = "zh-CN"\ntheme = "dark"\n'
    (config_home / 'config.toml').write_text(config)
    originals = {p.name: p.read_bytes() for p in config_home.iterdir()}
    (REPORT / 'config-original.toml').write_bytes(originals['config.toml'])
    execute(['/bin/launchctl', 'setenv', 'CODEX_HOME', config_home])
    script_env = dict(os.environ, CODEX_HOME=str(config_home), PATH='/usr/bin:/bin:/usr/sbin:/sbin', PYTHONUNBUFFERED='1')
    payload = (REPO / 'docs/public/install/chinese.sh').read_bytes()
    if args.old:
        payload = subprocess.check_output(['git', 'show', '5e228f0:docs/public/install/chinese.sh'], cwd=REPO)
        require(hashlib.sha256(payload).hexdigest() == 'd5c1596d4c3de3003836f6911e3bed3e13a2b66ac6b9ad7455fd7b43b5a592a2', 'Old comparison bytes differ')
    report['scriptSha256'] = hashlib.sha256(payload).hexdigest()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a): pass
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        execute(['/usr/bin/swiftc', REPO / 'tests/chinese-macos-window.swift', '-o', ROOT / 'window-reader'], timeout=180)
        execute(['/bin/bash', '-n', REPO / 'docs/public/install/chinese.sh'])
        execute(['/bin/sh', '-n', REPO / 'docs/public/install/chinese.sh'])
        report['systemPython'] = execute(['/usr/bin/python3', '--version']).stdout
        set_network(args.network)
        if args.auth == 'apikey':
            onboarding()
        report['baseline'] = snapshot('baseline')
        if args.network != 'online':
            require(not any(x.get('source') == 'Network' for x in report['baseline']['caches']), 'Offline baseline leaked to network')
        open_app()
        time.sleep(5)
        if args.old:
            run_tool('old-control', False)
        else:
            run_tool('run1-open')
            run_tool('run2-repeat', previous=True)
            stop()
            run_tool('run3-closed', previous=True)
            for n in range(1, 4):
                run_tool(f'stress{n}', previous=True)
            report['final'] = snapshot('final')
            require(report['final']['liveEnableI18n'] is True and report['final']['cjkCount'] >= 5, 'Final language/cache not enabled')
            if args.network == 'blackhole' and args.auth == 'apikey':
                run_tool('interrupted', False, interrupt=True)
                run_tool('after-interrupted', previous=True)
            (REPORT / 'config-final.toml').write_bytes((config_home / 'config.toml').read_bytes())
            comparison = execute([sys.executable, REPO / 'tests/chinese-config-preservation.py', REPORT / 'config-original.toml', REPORT / 'config-final.toml'])
            report['originalSettings'] = json.loads(comparison.stdout)
            require(report['originalSettings']['preserved'], 'Original user configuration values changed')
            require(all((config_home / name).read_bytes() == data for name, data in originals.items() if name != 'config.toml'), 'Original authentication data changed')
            require(not list(config_home.glob('config.toml.codex-zh.bak.*')), 'Tool added a config backup')
            require({str(p): digest(p) for p in files} == original_hashes, 'Application files changed')
            execute(['/usr/bin/codesign', '--verify', '--deep', '--strict', app])
            report['originalConfigValuesPreserved'] = True
            report['applicationUnchanged'] = True
    except Exception as error:
        report['failures'].append(str(error))
        raise
    finally:
        stop()
        try:
            save_databases()
        except Exception as error:
            report['databaseCaptureError'] = str(error)
        execute(['sudo', '/usr/bin/tee', '/etc/hosts'], input=hosts.decode())
        flush_dns()
        if prior_home:
            execute(['/bin/launchctl', 'setenv', 'CODEX_HOME', prior_home])
        else:
            execute(['/bin/launchctl', 'unsetenv', 'CODEX_HOME'])
        server.shutdown()
        save()
