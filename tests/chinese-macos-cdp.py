"""Exercise the production Mac transport against the existing deterministic network fixture."""
import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time
import uuid
sys.dont_write_bytecode = True
repo = Path(__file__).resolve().parents[1]
core = runpy.run_path(str(repo / 'usegoodai-codex-installer/codex-zh/macos/chinese.py'))
report = Path(os.environ.get('RUNNER_TEMP', str(repo / '.git/local-archive/windows-chinese-20261120'))) / 'mac-cdp'
report.mkdir(parents=True, exist_ok=True)
results = []
for name, mode, reload, success in [
    ('receive-hang', 'receive-hang', False, False),
    ('handshake-hang', 'handshake-hang', False, False),
    ('send-hang', 'send-hang', False, False),
    ('unrelated-events', 'events', False, False),
    ('page-changed', 'race', False, True),
    ('permanent-page-change', 'always-race', False, False),
    ('unrelated-error', 'other-error', False, False),
    ('fragmented', 'fragmented', False, True),
    ('reload-page-change', 'always-race', True, False),
]:
    ready = report / (name + '-' + uuid.uuid4().hex + '.ready')
    fixture_errors = (report / (name + '-fixture-stderr.txt')).open('w')
    fixture = subprocess.Popen([sys.executable, str(repo / 'tests/codex-chinese-network.py'), '--mode', mode, '--ready', str(ready)], stdout=subprocess.DEVNULL, stderr=fixture_errors)
    output = io.StringIO()
    stage = 'fixture-startup'
    try:
        deadline = time.monotonic() + 10
        while not ready.exists() and fixture.poll() is None and time.monotonic() < deadline:
            time.sleep(.1)
        assert ready.exists(), (name, 'Fixture did not start', fixture.poll(), sys.executable)
        port = int(ready.read_text())
        stage = 'evaluate'
        expression = 'location.reload(); "reload-requested"' if reload else ('"' + 'x' * (16*1024*1024) + '"' if mode == 'send-hang' else 'JSON.stringify({ok:true})')
        started = time.monotonic()
        error = None
        with contextlib.redirect_stdout(output):
            try:
                with core['progress']('正在等待 ChatGPT 加载'):
                    result = core['call'](port, expression, 12)
                passed = bool(result.get('ok'))
            except Exception as exc:
                passed = False
                error = str(exc)
        seconds = time.monotonic() - started
        attempts = int(ready.with_suffix('.attempts').read_text()) if ready.with_suffix('.attempts').exists() else 0
        assert passed == success, (name, passed, error)
        assert seconds < 15, (name, seconds)
        if mode in ('receive-hang', 'handshake-hang', 'send-hang', 'events', 'always-race') and not reload:
            assert seconds >= 10 and '已等待 5 秒' in output.getvalue(), (name, seconds, output.getvalue())
        if mode == 'other-error' or reload:
            assert attempts == 1, (name, attempts)
        if mode == 'race':
            assert attempts == 2, (name, attempts)
        results.append(dict(name=name, passed=True, seconds=round(seconds,2), attempts=attempts, error=error))
        print(name, 'PASS', round(seconds,2), flush=True)
    except Exception as exc:
        results.append(dict(name=name, passed=False, stage=stage, error=str(exc), fixtureExit=fixture.poll(), python=sys.version, executable=sys.executable))
        raise
    finally:
        if fixture.poll() is None:
            fixture.terminate()
        fixture.wait(10)
        fixture_errors.close()
        (report / (name + '.txt')).write_text(output.getvalue())
        (report / 'report.json').write_text(json.dumps(results, indent=2))
