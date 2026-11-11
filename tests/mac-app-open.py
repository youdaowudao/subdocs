#!/usr/bin/env python3
"""在真实 Mac 上按客户方式打开签好的 Mac 工具：浏览器下载（带隔离标记）→ 解压 → 双击。

记录每个 App 的 codesign、spctl、syspolicy_check 判定，实际 open 后截屏、检查程序是否运行；
截取「隐私与安全性」页面；用 spctl --add 模拟用户点「仍要打开」后再打开；
并检查生图 App 内部的工具程序在放行后能否执行。不使用任何密钥。

用法：python3 tests/mac-app-open.py 合集.zip [Mac助手.zip ...]
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

WORK = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'mac-app-open'
REPORT = WORK / 'report'


def run(command, timeout=120):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        return {'code': result.returncode, 'out': (result.stdout + result.stderr).strip()[-3000:]}
    except subprocess.TimeoutExpired:
        return {'code': 'timeout', 'out': ''}


def quarantine():
    return f'0083;{int(time.time()):x};Safari;{str(uuid.uuid4()).upper()}'


def screenshot(label):
    path = REPORT / f'{label}.png'
    run(['/usr/sbin/screencapture', '-x', str(path)])
    return path.name if path.exists() else None


def running(app):
    out = run(['/bin/ps', '-axo', 'pid,comm'])['out']
    return [line.strip() for line in out.splitlines() if str(app) in line or 'Terminal.app' in line]


def reset():
    for name in ['Terminal', 'CoreServicesUIAgent', 'launcher', 'System Settings']:
        run(['/usr/bin/killall', name])
    time.sleep(2)


def open_and_watch(app, label):
    opened = run(['/usr/bin/open', str(app)], timeout=30)
    time.sleep(10)
    result = {'open': opened, 'screenshot': screenshot(label), 'running_after_10s': running(app)}
    reset()
    return result


def main():
    REPORT.mkdir(parents=True, exist_ok=True)
    report = {'system': run(['/usr/bin/sw_vers'])['out'], 'zips': {}}
    for index, archive in enumerate(Path(arg) for arg in sys.argv[1:]):
        source = WORK / f'download-{index}.zip'
        source.write_bytes(archive.read_bytes())
        run(['/usr/bin/xattr', '-w', 'com.apple.quarantine', quarantine(), str(source)])
        folder = WORK / f'extract-{index}'
        run(['/usr/bin/ditto', '-x', '-k', str(source), str(folder)])
        apps = sorted(p for p in folder.rglob('*.app') if not any(q.suffix == '.app' for q in p.parents))
        results = {}
        for app in apps:
            run(['/usr/bin/xattr', '-rw', 'com.apple.quarantine', quarantine(), str(app)])
            name = app.stem
            info = {
                'codesign_verify': run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '-vv', str(app)]),
                'codesign_display': run(['/usr/bin/codesign', '-dvv', str(app)]),
                'spctl': run(['/usr/sbin/spctl', '--assess', '--type', 'execute', '-vv', str(app)]),
                'syspolicy_check': run(['/usr/bin/syspolicy_check', 'distribution', str(app)]),
            }
            info['first_open'] = open_and_watch(app, f'{index}-{name}-首次双击')
            # 被拦后「隐私与安全性」底部应出现「仍要打开」；“已损坏”时没有这个按钮。
            run(['/usr/bin/open', 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'])
            time.sleep(6)
            info['privacy_pane'] = screenshot(f'{index}-{name}-隐私与安全性')
            reset()
            # 模拟用户点「仍要打开」：把这个 App 加入系统的放行名单。
            info['approve'] = run(['/usr/bin/sudo', '/usr/sbin/spctl', '--add', '--label', 'UseGoodAI-test', str(app)])
            info['spctl_after_approve'] = run(['/usr/sbin/spctl', '--assess', '--type', 'execute', '-vv', str(app)])
            info['open_after_approve'] = open_and_watch(app, f'{index}-{name}-放行后双击')
            tool = app / 'Contents' / 'Resources' / 'tool'
            if tool.exists():
                # 生图 App 由终端里的 run.command 调用内部程序；它同样带着隔离标记。
                info['inner_tool_quarantine'] = run(['/usr/bin/xattr', '-p', 'com.apple.quarantine', str(tool)])['out']
                info['inner_tool_version'] = run([str(tool), 'version'], timeout=60)
                time.sleep(3)
                info['inner_tool_screenshot'] = screenshot(f'{index}-{name}-内部程序')
                reset()
            results[name] = info
            print(json.dumps({name: {
                'codesign_verify': info['codesign_verify']['out'][-160:],
                'spctl': info['spctl']['out'][-160:],
                'first_running': info['first_open']['running_after_10s'],
                'approve': info['approve'],
                'after_approve_running': info['open_after_approve']['running_after_10s'],
                'inner_tool': info.get('inner_tool_version'),
            }}, ensure_ascii=False, indent=1), flush=True)
        report['zips'][archive.name] = results
    (REPORT / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
