"""Run the candidate in an interactive Windows 10 Enterprise evaluation VM.

Only a disposable Actions Linux runner may provision it. Product checks run
inside Windows after interactive logon, never in Windows Server or Session 0.
"""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[3]
IMAGE = 'dockurr/windows@sha256:16fd7c39a3e48bb946d29c59dc6015942e5b900a1fa5d7e5552053bfc48ee2ea'


def run(args, timeout=600, check=True):
    result = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    if check and result.returncode:
        # Installer URLs can carry temporary query credentials; never echo them.
        detail = re.sub(r'https?://[^\s]+', '[download URL]', result.stderr[-1200:])
        raise RuntimeError(f'{args[0]} exited {result.returncode}: {detail}')
    return result


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') != 'Linux':
        raise SystemExit('This provisioner only runs in an isolated GitHub Linux VM.')
    root = Path(os.environ['RUNNER_TEMP']) / 'chinese-win10'
    root.mkdir()
    report = root / 'shared/report'
    report.mkdir(parents=True)
    # Remove only preinstalled, unused SDKs in this disposable runner if the
    # Microsoft evaluation image otherwise cannot fit. Never run on the host.
    if shutil.disk_usage(root).free < 32 * 1024**3:
        cleanup = "import shutil; [shutil.rmtree(p, ignore_errors=True) for p in ['/usr/local/lib/android','/usr/share/dotnet','/opt/ghc','/opt/hostedtoolcache/CodeQL']]"
        run(['sudo', 'python3', '-c', cleanup])
    if shutil.disk_usage(root).free < 32 * 1024**3:
        raise RuntimeError('Windows 10 VM needs at least 32 GiB available; no UI checks ran.')
    if not Path('/dev/kvm').exists():
        raise RuntimeError('This runner has no KVM acceleration; no Windows UI checks ran.')
    oem = root / 'oem'
    shutil.copytree(Path(__file__).parent / 'win10-oem', oem)
    for name in ['tests/codex-chinese-desktop.ps1', 'docs/public/install/chinese.ps1',
                 'usegoodai-codex-installer/quick-connect/tools/windows_chinese_ui.ps1']:
        target = oem / 'repo' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / name, target)
    shutil.copyfile(REPO / 'docs/public/download/usegoodai-quick-connect-windows-x64.exe', oem / 'candidate.exe')
    storage = root / 'storage'
    storage.mkdir()
    name = 'usegoodai-chinese-win10-' + os.environ['GITHUB_RUN_ID']
    started = time.monotonic()
    (report / 'host.json').write_text(json.dumps({'image': IMAGE, 'commit': os.environ['GITHUB_SHA'], 'minimumFreeBytes': shutil.disk_usage(root).free}, indent=2))
    try:
        run(['docker', 'run', '-d', '--name', name, '--device=/dev/kvm', '--device=/dev/net/tun',
             '--cap-add=NET_ADMIN', '-p', '127.0.0.1:8006:8006', '-e', 'VERSION=10e',
             '-e', 'LANGUAGE=Chinese', '-e', 'USERNAME=UseGoodAITest', '-e', 'RAM_SIZE=4G',
             '-e', 'CPU_CORES=2', '-e', 'DISK_SIZE=32G',
             '-v', f'{storage}:/storage', '-v', f'{oem}:/oem', '-v', f'{root / "shared"}:/shared', IMAGE], timeout=600)
        last_cases = -1
        while time.monotonic() - started < 2700:
            completion = report / 'completion.json'
            if completion.exists():
                result = json.loads(completion.read_text(encoding='utf-8-sig'))
                if not result.get('passed'):
                    raise RuntimeError('Windows 10 did not pass: ' + json.dumps(result, ensure_ascii=False))
                print('Windows 10 desktop UI integration passed.', flush=True)
                return
            cases = report / 'report.json'
            if cases.exists():
                try:
                    count = len(json.loads(cases.read_text(encoding='utf-8-sig')).get('cases', []))
                    if count != last_cases:
                        print(f'Windows 10 completed UI cases: {count}', flush=True)
                        last_cases = count
                except (ValueError, OSError):
                    pass
            elapsed = int(time.monotonic() - started)
            print(f'Waiting for Windows 10 desktop integration: {elapsed}s', flush=True)
            if elapsed > 1500 and not (report / 'environment.json').exists():
                raise RuntimeError('Windows 10 interactive desktop did not become ready; UI remains unverified.')
            state = run(['docker', 'inspect', '-f', '{{.State.Running}}', name], check=False).stdout.strip()
            if state != 'true':
                raise RuntimeError('Windows 10 VM stopped before producing a test result.')
            time.sleep(30)
        raise RuntimeError('Windows 10 UI integration exceeded the bounded test duration.')
    finally:
        logs = run(['docker', 'logs', name], check=False)
        sanitized = re.sub(r'https?://[^\s]+', '[download URL]', logs.stdout + logs.stderr)
        (report / 'vm.log').write_text(sanitized)
        run(['docker', 'stop', '-t', '30', name], timeout=60, check=False)


if __name__ == '__main__':
    main()
