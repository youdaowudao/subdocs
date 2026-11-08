#!/usr/bin/env python3
"""Release gate: real Apple Silicon, official desktop backend, system sh/Bash and JXA."""

import copy
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import platform
import plistlib
import shlex
import shutil
import subprocess
import sys
from threading import Thread
import tomllib
import xml.etree.ElementTree as ET
import zipfile


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
WORK = Path(os.environ['RUNNER_TEMP']) / 'mac-model-import-gate'
REPORT = WORK / 'report'
REPORT.mkdir(parents=True, exist_ok=True)
SCRIPT = ROOT / 'install/codex-models.sh'
FEED = 'https://persistent.oaistatic.com/codex-app-prod/appcast.xml'
SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
CHECKS = []


def check(name, action):
    try:
        action()
    except Exception as error:
        CHECKS.append({'name': name, 'passed': False, 'error': str(error)})
        print(f'FAIL {name}: {error}', flush=True)
    else:
        CHECKS.append({'name': name, 'passed': True})
        print(f'PASS {name}', flush=True)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def execute(name, command, *, env=None, input=None, timeout=180):
    result = subprocess.run(command, env=env, input=input, text=True, capture_output=True, timeout=timeout)
    (REPORT / f'{name}.stdout.txt').write_text(result.stdout)
    (REPORT / f'{name}.stderr.txt').write_text(result.stderr)
    if result.returncode:
        print(f'{name}: exit {result.returncode}\n{result.stdout[-3000:]}\n{result.stderr[-6000:]}', flush=True)
    return result


def download(url, target):
    result = execute('download-' + target.stem,
                     ['/usr/bin/curl', '-fSL', '--retry', '2', '--connect-timeout', '15',
                      '--max-time', '540', '-o', str(target), url], timeout=600)
    require(result.returncode == 0, f'Download failed: {url}')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


ORIGINAL = {
    'model': 'gpt-6.1-sol', 'model_provider': 'relay',
    'model_providers': {'relay': {'name': 'test', 'base_url': 'https://example.invalid/v1',
                                'wire_api': 'responses', 'requires_openai_auth': False}},
    'desktop': {'theme': 'dark'}, 'features': {'test-preserve-unknown': True},
}
CONFIG = ('model = "gpt-6.1-sol"\nmodel_provider = "relay"\n'
          '[model_providers.relay]\nname = "test"\nbase_url = "https://example.invalid/v1"\n'
          'wire_api = "responses"\nrequires_openai_auth = false\n'
          '[desktop]\ntheme = "dark"\n[features]\ntest-preserve-unknown = true\n')
AUTH = b'{"diagnostic":"synthetic-credential-must-not-leak"}\n'


def home_for(name):
    home = WORK / ('用户 目录 ' + name)
    home.mkdir()
    (home / 'config.toml').write_text(CONFIG)
    (home / 'auth.json').write_bytes(AUTH)
    return home


def environment(home):
    return dict(os.environ, CODEX_HOME=str(home), PATH='/usr/bin:/bin:/usr/sbin:/sbin')


def verify_import(home, backend):
    config = tomllib.loads((home / 'config.toml').read_text())
    for key in ['model', 'model_provider', 'model_providers', 'features']:
        require(config[key] == ORIGINAL[key], f'{key} changed')
    require(config['desktop']['theme'] == 'dark', 'Desktop appearance changed')
    require('windows' not in config and 'sandbox_mode' not in config, 'Unrelated sandbox setting added')
    require((home / 'auth.json').read_bytes() == AUTH, 'Credential changed')
    require(Path(config['model_catalog_json']) == home / 'usegoodai-models.json', 'Wrong model catalog path')
    models = json.loads((home / 'usegoodai-models.json').read_text())['models']
    ids = [model['slug'] for model in models]
    managed = json.loads((home / 'usegoodai-models.managed.json').read_text())
    expected = [model['slug'] for model in json.loads((ROOT / 'src/models.json').read_text())['models']]
    require(sorted(managed) == sorted(expected) and len(managed) == 10, 'Wrong managed models')
    require(len(ids) == len(set(ids)), 'Duplicate model IDs')
    require('gpt-6.1-terra' in ids and all(item in ids for item in managed), 'Missing models')
    native = execute('native-validate-' + home.name, [str(backend), 'debug', 'models'], env=environment(home))
    require(native.returncode == 0, 'Official backend rejected the imported catalog')
    native_ids = [model['slug'] for model in json.loads(native.stdout)['models']]
    require(all(item in native_ids for item in managed), 'Official backend did not load domestic models')
    return models


def import_file(name, interpreter, backend, *, explicit=None, script=SCRIPT, home=None):
    home = home or home_for(name)
    arguments = ['--codex-home', str(home)]
    if explicit is not None:
        arguments += ['--codex-path', str(explicit)]
    result = execute(name, [interpreter, str(script), *arguments], env=environment(home))
    require(result.returncode == 0, f'Importer exited {result.returncode}')
    require('已导入 10 个国产模型' in result.stdout, 'No complete import receipt')
    require('synthetic-credential-must-not-leak' not in result.stdout + result.stderr, 'Credential leaked')
    verify_import(home, backend)
    return home


def main():
    require(sys.platform == 'darwin' and platform.machine() == 'arm64', 'A real Apple Silicon Mac is required')
    (REPORT / 'system.txt').write_text(subprocess.check_output(['/usr/bin/sw_vers'], text=True))
    require(all(path.read_bytes() == SCRIPT.read_bytes() for path in [
        ROOT.parent / 'install/codex-models.sh', REPO / 'docs/public/install/codex-models.sh']),
        'The three candidate script copies differ')
    for interpreter in ['/bin/sh', '/bin/bash']:
        def syntax(interpreter=interpreter):
            result = execute(Path(interpreter).name + '-syntax', [interpreter, '-n', str(SCRIPT)])
            require(result.returncode == 0, 'System shell cannot parse the complete installer')
        check('system syntax ' + interpreter, syntax)
    download(FEED, WORK / 'appcast.xml')
    release = ET.parse(WORK / 'appcast.xml').find('./channel/item')
    url = release.find('enclosure').attrib['url']
    require(url.startswith('https://persistent.oaistatic.com/codex-app-prod/'), 'Unexpected official package host')
    download(url, WORK / 'official.zip')
    package_sha = digest(WORK / 'official.zip')
    with zipfile.ZipFile(WORK / 'official.zip') as archive:
        app_name = next(name.split('/')[0] for name in archive.namelist()
                        if name.endswith('.app/Contents/Info.plist') and name.count('/') == 2)
    unpacked = WORK / 'unpacked'
    result = execute('unpack-official', ['/usr/bin/ditto', '-x', '-k', str(WORK / 'official.zip'), str(unpacked)])
    require(result.returncode == 0, 'Cannot unpack official app')
    app = Path('/Applications') / app_name
    require(not app.exists(), f'Refusing to replace pre-existing app: {app}')
    result = execute('install-official', ['/usr/bin/sudo', '/usr/bin/ditto', str(unpacked / app_name), str(app)])
    require(result.returncode == 0, 'Cannot install official app')
    shutil.rmtree(unpacked)
    (WORK / 'official.zip').unlink()
    backend = app / 'Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex'
    wrapper = app / 'Contents/Resources/codex-cli/bin/codex'
    require(backend.is_file(), 'Official backend location changed; review discovery before releasing')
    version = execute('backend-version', [str(backend), '--version'])
    require(version.returncode == 0, 'Official backend cannot start')
    (REPORT / 'release.json').write_text(json.dumps({
        'official_url': url, 'official_sha256': package_sha, 'backend': str(backend),
        'backend_version': version.stdout, 'candidate_sha256': digest(SCRIPT),
    }, indent=2))
    require(not execute('cli-in-path', ['/bin/sh', '-c', 'command -v codex'], env=environment(WORK)).stdout.strip(),
            'The default test must not be rescued by a preinstalled CLI')
    check('official App automatic discovery with system sh',
          lambda: import_file('automatic-sh', '/bin/sh', backend))
    check('system Bash 3.2 file entry', lambda: import_file('bash-file', '/bin/bash', backend))
    check('explicit native backend', lambda: import_file('explicit', '/bin/sh', backend, explicit=backend))
    check('official CLI wrapper', lambda: import_file('wrapper', '/bin/sh', backend, explicit=wrapper))

    payload = SCRIPT.read_bytes()
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    Thread(target=server.serve_forever, daemon=True).start()
    try:
        def pipeline():
            home = home_for('http-pipeline')
            curl = subprocess.Popen(['/usr/bin/curl', '-fsSL', f'http://127.0.0.1:{server.server_port}/codex-models.sh'],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            shell = subprocess.Popen(['/bin/sh', '-s', '--', '--codex-home', str(home)],
                                     stdin=curl.stdout, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     env=environment(home), text=True)
            curl.stdout.close()
            stdout, stderr = shell.communicate(timeout=180)
            curl_error = curl.stderr.read()
            curl.wait(timeout=30)
            (REPORT / 'pipeline.stdout.txt').write_text(stdout)
            (REPORT / 'pipeline.stderr.txt').write_text(stderr + curl_error)
            require(shell.returncode == 0 and curl.returncode == 0,
                    f'Pipeline failed: sh={shell.returncode}, curl={curl.returncode}; {stderr}')
            verify_import(home, backend)
        check('HTTP curl | system sh', pipeline)
    finally:
        server.shutdown()
        server.server_close()

    def update_and_uninstall():
        home = import_file('update-first', '/bin/sh', backend)
        path = home / 'usegoodai-models.json'
        catalog = json.loads(path.read_text())
        custom = copy.deepcopy(next(model for model in catalog['models'] if model['slug'].startswith('gpt-')))
        custom['slug'] = 'user-custom-kept'
        custom['display_name'] = 'User custom'
        catalog['models'].append(custom)
        path.write_text(json.dumps(catalog))
        import_file('update-second', '/bin/sh', backend, home=home)
        require('user-custom-kept' in [model['slug'] for model in json.loads(path.read_text())['models']],
                'User model lost on repeated import')
        config_before = (home / 'config.toml').read_bytes()
        result = execute('uninstall', ['/bin/sh', str(SCRIPT), '--codex-home', str(home), '--uninstall'], env=environment(home))
        require(result.returncode == 0, 'Uninstall failed')
        remaining = [model['slug'] for model in json.loads(path.read_text())['models']]
        require('user-custom-kept' in remaining and 'gpt-6.1-terra' in remaining, 'Uninstall removed retained models')
        require(json.loads((home / 'usegoodai-models.managed.json').read_text()) == [], 'Managed list not cleared')
        require((home / 'config.toml').read_bytes() == config_before and (home / 'auth.json').read_bytes() == AUTH,
                'Uninstall changed connection, default model or auth')
    check('repeated import preserves custom models; uninstall preserves GPT and configuration', update_and_uninstall)

    def malformed():
        home = home_for('invalid-config')
        (home / 'config.toml').write_text('model = [\n')
        before = {path.name: digest(path) for path in home.iterdir()}
        result = execute('malformed', ['/bin/sh', str(SCRIPT), '--codex-home', str(home)], env=environment(home))
        require(result.returncode != 0, 'Invalid configuration was accepted')
        require(before == {path.name: digest(path) for path in home.iterdir()}, 'Failed import altered files')
        require('synthetic-credential-must-not-leak' not in result.stdout + result.stderr, 'Credential leaked')
    check('failed import preserves existing files', malformed)

    def shipped_app():
        archive_path = REPO / 'docs/public/download/usegoodai-tools.zip'
        prefix = 'Mac-Apple芯片/3.Codex国产模型导入.app/'
        app_dir = WORK / 'shipped'
        with zipfile.ZipFile(archive_path) as archive:
            require(archive.read(prefix + 'Contents/Resources/install.sh') == SCRIPT.read_bytes(), 'Shipped app script is stale')
            for info in archive.infolist():
                if info.filename.startswith(prefix) and not info.is_dir():
                    target = app_dir / info.filename[len('Mac-Apple芯片/'):]
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(info))
                    target.chmod((info.external_attr >> 16) & 0o777)
        home = home_for('shipped-app')
        runner = app_dir / '3.Codex国产模型导入.app/Contents/Resources/run.command'
        result = execute('shipped-app-runner', ['/bin/bash', str(runner)], env=environment(home), input='\n')
        require(result.returncode == 0, 'Shipped app terminal runner failed')
        verify_import(home, backend)
    check('delivered third app runs the candidate installer', shipped_app)

    (REPORT / 'checks.json').write_text(json.dumps(CHECKS, ensure_ascii=False, indent=2))
    summary = '### Mac 国产模型导入门禁\n\n' + '\n'.join(
        f"- {'PASS' if item['passed'] else 'FAIL'} {item['name']}" for item in CHECKS) + '\n'
    (REPORT / 'summary.md').write_text(summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write(summary)
    print(summary, flush=True)
    return 0 if all(item['passed'] for item in CHECKS) else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        (REPORT / 'gate-error.txt').write_text(f'{type(error).__name__}: {error}\n')
        raise
