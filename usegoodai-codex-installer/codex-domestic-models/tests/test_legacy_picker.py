#!/usr/bin/env python3
"""Check the real app-server picker after importing with old Codex binaries."""
import argparse
from collections import Counter
import copy
import json
import os
from pathlib import Path
from queue import Empty, Queue
import subprocess
from tempfile import TemporaryDirectory
from threading import Thread
import tomllib


ROOT = Path(__file__).resolve().parents[1]
NEW_MODELS = {'gpt-6.2-sol', 'gpt-6.2-astra'}
DEFAULT = 'gpt-6.1-sol'
CUSTOM = 'user-custom-kept'
AUTH = b'{"OPENAI_API_KEY":"sk-legacy-picker-test-fixture"}\n'


def picker(codex, home):
    env = dict(os.environ, CODEX_HOME=str(home))
    with subprocess.Popen([codex, 'app-server'], cwd=home, env=env, text=True, encoding='utf-8',
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as server:
        output = Queue()
        def read_output():
            for line in server.stdout:
                output.put(line)

        reader = Thread(target=read_output, daemon=True)
        reader.start()

        def send(message):
            server.stdin.write(json.dumps(message) + '\n')
            server.stdin.flush()

        def response(request_id):
            try:
                while True:
                    event = json.loads(output.get(timeout=30))
                    if event.get('id') == request_id:
                        if 'error' in event:
                            raise AssertionError(event['error'])
                        return event['result']
            except Empty as error:
                raise AssertionError(f'app-server did not answer request {request_id}') from error

        try:
            send({'id': 1, 'method': 'initialize', 'params': {
                'clientInfo': {'name': 'usegoodai-legacy-picker-test', 'version': '1.0.0'}}})
            response(1)
            send({'method': 'initialized'})
            send({'id': 2, 'method': 'model/list', 'params': {'includeHidden': False}})
            return response(2)['data']
        finally:
            server.terminate()
            server.wait(timeout=10)
            reader.join(timeout=5)


def run_import(script, codex, home, pwsh):
    env = dict(os.environ, CODEX_HOME=str(home))
    if script.suffix == '.ps1':
        # On Linux the test runs the exact PowerShell installer with Windows
        # file semantics selected, in addition to the native Windows GUI check.
        env['OS'] = 'Windows_NT'
        command = [pwsh, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script,
                   '-CodexHomePath', home, '-CodexPath', codex]
    else:
        command = ['/bin/sh', script, '--codex-home', home, '--codex-path', codex]
    result = subprocess.run(command, cwd=home, env=env,
                            text=True, encoding='utf-8', capture_output=True, timeout=90)
    if result.returncode:
        raise AssertionError(f'{script.name} failed: {result.stdout}\n{result.stderr}')


def check_models(codex, home, config, custom, domestic, *, upgraded):
    models = picker(codex, home)
    counts = Counter(row['id'] for row in models)
    assert set(domestic) <= counts.keys(), 'Missing domestic models in the visible picker'
    for slug in [*domestic, CUSTOM]:
        assert counts[slug] == 1, f'Wrong picker count for {slug}: {counts[slug]}'
    for slug in NEW_MODELS:
        assert counts[slug] == int(upgraded), f'Wrong picker count for {slug}: {counts[slug]}'
    assert len(models) == len(counts), 'Duplicate entries in the visible picker'
    selected = tomllib.loads((home / 'config.toml').read_text(encoding='utf-8-sig'))
    for field in ('model', 'model_provider', 'model_providers', 'approval_policy'):
        assert selected[field] == config[field], f'{field} changed'
    assert (home / 'auth.json').read_bytes() == AUTH, 'Credentials changed'
    saved = json.loads((home / 'usegoodai-models.json').read_text(encoding='utf-8-sig'))
    assert [row for row in saved['models'] if row['slug'] == CUSTOM] == [custom], 'Custom model was rewritten'
    assert selected['model'] == DEFAULT and counts[DEFAULT] == 1


def verify(codex, old_scripts, pwsh):
    version = subprocess.check_output([codex, '--version'], text=True).strip().split()[-1]
    assert version in ('0.162.1', '0.165.0'), f'Unexpected test binary: {version}'
    work = ROOT / 'tests/.work'
    work.mkdir(exist_ok=True)
    with TemporaryDirectory(dir=work) as directory:
        root = Path(directory)
        bundled = json.loads(subprocess.check_output(
            [codex, 'debug', 'models', '--bundled'], cwd=root,
            env=dict(os.environ, CODEX_HOME=str(root)), text=True, encoding='utf-8'))
        assert all(row['slug'] not in NEW_MODELS for row in bundled['models']), 'Old binary contains new models'
        custom = copy.deepcopy(next(row for row in bundled['models'] if row['slug'] == DEFAULT))
        custom.update(slug=CUSTOM, display_name='UseGoodAI custom fixture')
        domestic = [row['slug'] for row in json.loads((ROOT / 'src/models.json').read_text())['models']]
        assert len(domestic) == 10
        for old_script in old_scripts:
            candidate = ROOT / 'install' / old_script.name
            for scenario in ('no-cache', 'old-cache', 'replace-old', 'repeat'):
                home = root / f'{old_script.suffix[1:]}-{scenario}'
                home.mkdir()
                (home / 'custom.json').write_text(json.dumps({'models': [custom]}), encoding='utf-8')
                config_text = (
                    f'model = "{DEFAULT}"\nmodel_provider = "fixture"\n'
                    'model_catalog_json = "custom.json"\napproval_policy = "never"\n'
                    '[model_providers.fixture]\nname = "Local fixture"\n'
                    'base_url = "http://127.0.0.1:9/v1"\nwire_api = "responses"\n'
                )
                (home / 'config.toml').write_text(config_text, encoding='utf-8')
                (home / 'auth.json').write_bytes(AUTH)
                config = tomllib.loads(config_text)
                cache = home / 'models_cache.json'
                if scenario == 'old-cache':
                    cache.write_text(json.dumps({
                        'client_version': version, 'fetched_at': '2026-11-17T00:00:00Z',
                        'etag': 'old-fixture', 'models': bundled['models'],
                    }), encoding='utf-8')
                before_cache = cache.read_bytes() if cache.exists() else None
                if scenario in ('replace-old', 'repeat'):
                    run_import(old_script, codex, home, pwsh)
                    check_models(codex, home, config, custom, domestic, upgraded=False)
                run_import(candidate, codex, home, pwsh)
                check_models(codex, home, config, custom, domestic, upgraded=True)
                if scenario == 'repeat':
                    files = ('config.toml', 'usegoodai-models.json', 'usegoodai-models.managed.json')
                    previous = [(home / path).read_bytes() for path in files]
                    run_import(candidate, codex, home, pwsh)
                    check_models(codex, home, config, custom, domestic, upgraded=True)
                    assert [(home / path).read_bytes() for path in files] == previous, 'Repeated import changed files'
                assert (cache.read_bytes() if cache.exists() else None) == before_cache, 'Cache changed'
                print(f'{version} {old_script.suffix[1:]} {scenario} PASS {DEFAULT}, custom, 10 domestic, both GPT-6.2',
                      flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--codex', type=Path, action='append', required=True)
    parser.add_argument('--old-script', type=Path, action='append', required=True)
    parser.add_argument('--pwsh', default='pwsh')
    args = parser.parse_args()
    for binary in args.codex:
        verify(binary.resolve(), [path.resolve() for path in args.old_script], args.pwsh)
