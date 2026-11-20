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
import urllib.request

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
    pids = CORE['running'](str(executable))
    if pids:
        # Prepare/read the fixture with an ordinary quit, independently of the
        # forced-close path under test. Killing the main process damaged its WAL.
        execute(['/usr/bin/osascript', '-e', 'tell application id "com.openai.codex" to quit'])
        require(CORE['wait_until'](lambda: not CORE['running'](str(executable)), 15), 'Ordinary application quit did not finish')
    CORE['stop_desktop'](str(executable), pids)


def open_app(debug=False):
    args = ['/usr/bin/open', '-a', app]
    if debug:
        args += ['--args', '--remote-debugging-port=9333', '--remote-allow-origins=http://127.0.0.1:9333']
    execute(args, env=script_env)
    require(CORE['wait_until'](lambda: CORE['running'](str(executable)), 15), 'Application did not start')


def listeners():
    result = execute(['/usr/sbin/lsof', '-nP', '-iTCP', '-sTCP:LISTEN'], check=False)
    pids = {str(pid) for pid in app_rows()}
    return [line for line in result.stdout.splitlines() if len(line.split()) > 1 and line.split()[1] in pids]


def app_rows():
    return {pid: row for pid, row in CORE['process_snapshot']().items()
            if row[1] == os.getuid() and not row[2].startswith('Z') and row[3].startswith(str(app) + '/Contents/')}


def app_processes():
    rows = app_rows()
    commands = execute(['/bin/ps', '-ww', '-axo', 'pid=,command=']).stdout.splitlines()
    return [line for line in commands if line.split() and line.split()[0].isdigit() and int(line.split()[0]) in rows]


def save_databases(label='final'):
    # Keep the real failed WAL if one occurs; no extra I/O between repair and
    # ordinary reopen. All reads/copies run only after the scenario has ended.
    support = Path.home() / 'Library/Application Support'
    copies = report.setdefault('databaseCopies', [])
    index = 0
    for base in support.iterdir():
        if not base.is_dir() or not any(name in base.name.lower() for name in ('codex', 'chatgpt')):
            continue
        for directory in base.rglob('leveldb'):
            if 'Local Storage' not in directory.parts:
                continue
            index += 1
            destination = REPORT / f"{label}-db{index}"
            shutil.copytree(directory, destination, ignore=shutil.ignore_patterns('LOCK'))
            copies.append({'phase': label, 'source': str(directory), 'copy': destination.name})


def storage_errors():
    support = Path.home() / 'Library/Application Support/Codex'
    return [{'path': str(log), 'lines': [line for line in log.read_text(errors='replace').splitlines()
                                      if re.search(r'Corruption:|IO error:', line)]}
            for log in support.rglob('Local Storage/leveldb/LOG*')
            if log.name in ('LOG', 'LOG.old')
            if re.search(r'Corruption:|IO error:', log.read_text(errors='replace'))]


def capture(label):
    pids = CORE['running'](str(executable))
    require(len(pids) == 1, 'Expected one normal main application process')
    window = execute([ROOT / 'window-reader', 'window', str(next(iter(pids)))]).stdout.strip()
    image = REPORT / (label + '.png')
    execute(['/usr/sbin/screencapture', '-x', '-l', window, image])
    text = execute([ROOT / 'window-reader', 'ocr', image]).stdout
    (REPORT / (label + '.txt')).write_text(text)
    return {'window': window, 'cjk': len(re.findall('[一-鿿]', text)), 'text': text}


def snapshot(label, diagnose=False):
    stop()
    open_app(True)
    try:
        windows = (REPO / 'tests/codex-chinese-desktop.ps1').read_text(encoding='utf-8-sig')
        js = re.search(r"\$snapshotJs = @'\n(.*?)\n'@", windows, re.S)[1]
        result = CORE['call'](9333, js, 100)
        result['browserLocale'] = CORE['call'](9333, 'JSON.stringify({language:navigator.language,languages:navigator.languages})', 10)
        if diagnose:
            expression = r'''
(() => {
 const root=window.__STATSIG__||globalThis.__STATSIG__;
 const clients=[root?.firstInstance,...Object.values(root?.instances||root?._instances||{})].filter((x,i,a)=>x&&typeof x.getContext==='function'&&a.indexOf(x)===i);
 return JSON.stringify({visible:document.visibilityState,href:location.href,text:(document.body?.innerText||'').slice(0,250),clients:clients.map(client=>{
  try {
   const context=client.getContext(),key=client.dataAdapter._getCacheKey(context.user),raw=localStorage.getItem(key),wrapper=raw?JSON.parse(raw):null;
   const payload=typeof wrapper?.data==='string'?JSON.parse(wrapper.data):wrapper?.data;
   const layer=client.getLayer('72216192',{disableExposureLog:true});
   return {first:client===root?.firstInstance,status:client.loadingStatus,key,cacheExists:!!raw,enableI18n:layer?.get('enable_i18n',null),localeSource:layer?.get('locale_source',null),stableMatches:wrapper?.stableID===context.stableID,cacheFormat:payload?.response_format,cacheHashUsed:payload?.hash_used,contextFormat:context.values?.response_format,contextHashUsed:context.values?.hash_used};
  } catch { return {readFailed:true}; }
 })});
})()
'''
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            with opener.open('http://127.0.0.1:9333/json/list', timeout=3) as response:
                targets = json.load(response)
            result['pages'] = []
            for target in targets:
                if target.get('type') == 'page' and target.get('url', '').startswith('app://') and target.get('webSocketDebuggerUrl'):
                    try:
                        result['pages'].append(CORE['evaluate'](target['webSocketDebuggerUrl'], expression, 10))
                    except Exception as error:
                        result['pages'].append({'readFailed': str(error)})
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
        row['storageErrors'] = storage_errors()
        save()
        require(not row['storageErrors'], label + ' reopened with cache database errors')
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
    return row


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--network', choices=['refused', 'blackhole', 'online'], required=True)
    parser.add_argument('--auth', choices=['apikey', 'login'], required=True)
    parser.add_argument('--focused', action='store_true')
    args = parser.parse_args()
    report.update(network=args.network, auth=args.auth, focused=args.focused, sha=os.environ.get('GITHUB_SHA'), system=platform.platform(), machine=platform.machine(), python=sys.version)
    require(sys.platform == 'darwin' and platform.machine() == 'arm64', 'A real Apple Silicon Mac is required')
    hosts = Path('/etc/hosts').read_bytes()
    preferences = Path.home() / 'Library/Preferences/.GlobalPreferences.plist'
    original_preferences = plistlib.loads(preferences.read_bytes()) if preferences.exists() else {}
    execute(['/usr/bin/defaults', 'write', '-g', 'AppleLanguages', '-array', 'zh-Hans', 'en-US'])
    execute(['/usr/bin/defaults', 'write', '-g', 'AppleLocale', 'zh_CN'])
    report['testSystemLanguages'] = execute(['/usr/bin/defaults', 'read', '-g', 'AppleLanguages']).stdout
    app = install()
    executable = app / 'Contents/MacOS/ChatGPT'
    files = [executable, app / 'Contents/Resources/app.asar']
    original_hashes = {str(p): digest(p) for p in files}
    payload = (REPO / 'docs/public/install/chinese.sh').read_bytes()
    report['scriptSha256'] = hashlib.sha256(payload).hexdigest()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a): pass
        def do_GET(self):
            if self.path.split('?', 1)[0] in ('/v1/models', '/models'):
                body = json.dumps({'object':'list','data':[{'id':'gpt-6.1-sol','object':'model','owned_by':'ci','created':0}]}).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if self.path != '/chinese.sh':
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    require(os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'Default profile is allowed only in a disposable hosted VM')
    config_home = Path.home() / '.codex'
    require(not any((config_home / name).exists() for name in ('config.toml', 'auth.json', 'sessions')), 'Refusing a pre-existing configured/authenticated/session profile')
    config_home.mkdir(exist_ok=True)
    config = '# preserve existing configuration\n'
    if args.auth == 'apikey':
        config += f'model_provider = "OpenAI"\nmodel = "gpt-6.1-sol"\n[model_providers.OpenAI]\nname = "OpenAI"\nbase_url = "http://127.0.0.1:{server.server_port}/v1"\nwire_api = "responses"\nrequires_openai_auth = true\n'
    config += '[desktop]\nlocaleOverride = "zh-CN"\ntheme = "dark"\n'
    (config_home / 'config.toml').write_text(config)
    script_env = dict(os.environ, CODEX_HOME=str(config_home), PYTHONUNBUFFERED='1')
    selected_python = execute(['/bin/sh', '-c', 'command -v python3'], env=script_env).stdout.strip()
    report['scriptPython'] = execute([selected_python, '--version'], env=script_env).stdout.strip()
    native_cli = app / 'Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex'
    require(native_cli.is_file(), 'Official bundled CLI is missing')
    report['nativeCliVersion'] = execute([native_cli, '--version'], env=script_env).stdout.strip()
    report['profileScope'] = 'default directory in a fresh disposable hosted VM'
    save()
    prior_login = subprocess.run([str(native_cli), 'login', 'status'], env=script_env, text=True, capture_output=True, timeout=30)
    require(prior_login.returncode != 0, 'Refusing pre-existing credentials in the hosted VM')
    if args.auth == 'apikey':
        login = subprocess.run([str(native_cli), 'login', '--with-api-key'], input='sk-ci-fake-key-not-real\n', env=script_env, text=True, capture_output=True, timeout=30)
        status = subprocess.run([str(native_cli), 'login', 'status'], env=script_env, text=True, capture_output=True, timeout=30)
        status_text = (status.stdout + status.stderr).lower()
        mode = 'api_key' if 'api' in status_text and ('key' in status_text or '密钥' in status_text) else 'unknown'
        report['nativeLogin'] = {'exit': login.returncode, 'statusExit': status.returncode, 'mode': mode}
        save()
        require(login.returncode == 0 and status.returncode == 0 and mode == 'api_key', 'Official fake-key login fixture is not ready')
    originals = {p.name: p.read_bytes() for p in config_home.iterdir() if p.is_file() and p.name in ('config.toml', 'auth.json')}
    (REPORT / 'config-original.toml').write_bytes(originals['config.toml'])
    try:
        execute(['/usr/bin/swiftc', REPO / 'tests/chinese-macos-window.swift', '-o', ROOT / 'window-reader'], timeout=180)
        execute(['/bin/bash', '-n', REPO / 'docs/public/install/chinese.sh'])
        execute(['/bin/sh', '-n', REPO / 'docs/public/install/chinese.sh'])
        report['systemPython'] = execute(['/usr/bin/python3', '--version']).stdout
        set_network(args.network)
        if args.auth == 'apikey':
            onboarding()
        report['baseline'] = snapshot('baseline')
        report['baselineStorageErrors'] = storage_errors()
        save()
        require(not report['baselineStorageErrors'], 'Fixture already has cache database errors before the product runs')
        if args.network != 'online':
            require(not any(x.get('source') == 'Network' for x in report['baseline']['caches']), 'Offline baseline leaked to network')
        open_app()
        time.sleep(5)
        run_tool('run1-open')
        if not args.focused:
            run_tool('run2-repeat', previous=True)
            stop()
            run_tool('run3-closed', previous=True)
            for n in range(1, 4):
                run_tool(f'stress{n}', previous=True)
        report['final'] = snapshot('final')
        require(report['final']['liveEnableI18n'] is True and report['final']['cjkCount'] >= 5, 'Final language/cache not enabled')
        if not args.focused and args.network == 'blackhole' and args.auth == 'apikey':
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
        # Preserve the failed ordinary-window outcome before any extra SDK read.
        # No getDataSync and no product mutation: only current layer/locale/key.
        stop()
        save_databases('failure-original')
        (REPORT / 'config-at-failure.toml').write_bytes((config_home / 'config.toml').read_bytes())
        try:
            report['failureInspection'] = snapshot('failure-inspection', diagnose=True)
        except Exception as inspection_error:
            report['failureInspectionError'] = str(inspection_error)
        raise
    finally:
        stop()
        if (config_home / 'config.toml').exists():
            (REPORT / 'config-at-exit.toml').write_bytes((config_home / 'config.toml').read_bytes())
        try:
            save_databases()
        except Exception as error:
            report['databaseCaptureError'] = str(error)
        execute(['sudo', '/usr/bin/tee', '/etc/hosts'], input=hosts.decode())
        flush_dns()
        for key in ('AppleLanguages', 'AppleLocale'):
            if key not in original_preferences:
                execute(['/usr/bin/defaults', 'delete', '-g', key], check=False)
            elif isinstance(original_preferences[key], list):
                execute(['/usr/bin/defaults', 'write', '-g', key, '-array', *original_preferences[key]])
            else:
                execute(['/usr/bin/defaults', 'write', '-g', key, str(original_preferences[key])])
        server.shutdown()
        save()
