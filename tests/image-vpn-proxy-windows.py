#!/usr/bin/env python3
"""复现 Windows 上开着 VPN（系统代理）时生图工具连不上 api.usegoodai.com。

在 GitHub 的 Windows 运行器上：
1. 安装 npm 上的官方 Codex 命令行版（与 Windows App 同一内核），Codex 以 Windows 沙箱运行。
2. 把已发布的生图工具（默认 V0.9.3）装进真实的 %USERPROFILE%\\.codex，写入临时假 Key。
3. 模拟 VPN 客户端的「系统代理」：本机 127.0.0.1:7890 代理写入注册表 Internet Settings；
   api.usegoodai.com 直连指向不可达地址，只有走代理才能连通。
4. 记录走系统代理的程序、直连、生图工具在 Codex 外和 Codex 内（连续两次新启动）的结果，
   以及 VPN 软件退出后诊断给出的说明。
复用 image-vpn-proxy-mac.py 中的替身模型、本地代理和结果解析。
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('mac_repro', HERE / 'image-vpn-proxy-mac.py')
mac = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mac)

REPO = HERE.parent
RELEASE_TOOL = REPO / 'docs/public/install/usegoodai-imagines-tool/releases/v0.9.3/usegoodai-imagines-tool-v0.9.3-windows-amd64.exe'
INTERNET_SETTINGS = r'Software\Microsoft\Windows\CurrentVersion\Internet Settings'
HOSTS = Path(os.environ.get('SystemRoot', r'C:\Windows')) / 'System32/drivers/etc/hosts'


def install_codex(report):
    npm = shutil.which('npm.cmd') or shutil.which('npm')
    result = subprocess.run([npm, 'install', '-g', '@openai/codex@latest'], capture_output=True, text=True, timeout=900)
    if result.returncode:
        raise SystemExit(f'无法安装 Codex：{result.stderr[-2000:]}')
    root = Path(subprocess.run([npm, 'root', '-g'], capture_output=True, text=True).stdout.strip())
    found = sorted((root / '@openai').rglob('codex.exe'))
    if not found:
        raise SystemExit('没有找到 codex.exe')
    backend = found[0]
    report['codex'] = {'backend': str(backend),
                       'version': subprocess.run([str(backend), '--version'], capture_output=True, text=True).stdout.strip()}
    return backend


def install_tool(source, codex_home, work, report):
    staged = work / 'download' / 'usegoodai-imagines-tool.exe'
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, staged)
    env = {key: value for key, value in os.environ.items() if key != 'CODEX_HOME'}
    result = subprocess.run([str(staged), 'install'], input='\n', env=env, capture_output=True, text=True,
                            encoding='utf-8', errors='replace', timeout=120)
    (work / 'report' / 'install.txt').write_text(result.stdout + '\n--- stderr ---\n' + result.stderr, encoding='utf-8')
    if result.returncode:
        raise SystemExit(f'生图工具安装失败：{result.stdout[-2000:]}{result.stderr[-2000:]}')
    tool_dir = codex_home / 'tools' / 'usegoodai-imagines-tool'
    (tool_dir / 'api-key').write_text(mac.FAKE_KEY + '\n')
    skill = (codex_home / 'skills' / 'usegoodai-image-generation' / 'SKILL.md').read_text(encoding='utf-8')
    match = re.search(r'^(.+?) generate --model ', skill, re.MULTILINE)
    if not match:
        raise SystemExit('已安装 Skill 中找不到工具命令')
    report['tool'] = {'source': str(source), 'sha256': mac.digest(source),
                      'installed': str(tool_dir / 'usegoodai-imagines-tool.exe'), 'skill_command': match.group(1)}
    return tool_dir / 'usegoodai-imagines-tool.exe', match.group(1)


def set_system_proxy(enabled):
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, INTERNET_SETTINGS, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, 'ProxyEnable', 0, winreg.REG_DWORD, 1 if enabled else 0)
        winreg.SetValueEx(key, 'ProxyServer', 0, winreg.REG_SZ, '127.0.0.1:7890')
        winreg.SetValueEx(key, 'ProxyOverride', 0, winreg.REG_SZ, 'localhost;127.*;<local>')


def read_system_proxy():
    import winreg
    values = {}
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, INTERNET_SETTINGS) as key:
        for name in ['ProxyEnable', 'ProxyServer', 'ProxyOverride', 'AutoConfigURL']:
            try:
                values[name] = winreg.QueryValueEx(key, name)[0]
            except OSError:
                pass
    return values


def simulate_vpn(report):
    real_ip = socket.gethostbyname(mac.API_HOST)
    proxy_server = mac.start_connect_proxy(real_ip)
    set_system_proxy(True)
    with open(HOSTS, 'a', encoding='ascii') as hosts:
        hosts.write(f'\n{mac.BLACKHOLE} {mac.API_HOST}\n')
    subprocess.run(['ipconfig', '/flushdns'], capture_output=True)
    time.sleep(2)
    info = {'real_ip': real_ip, 'registry': read_system_proxy(), 'resolved_after': socket.gethostbyname(mac.API_HOST)}

    started = time.time()
    request = urllib.request.Request(f'https://{mac.API_HOST}/v1/models', headers={'Authorization': f'Bearer {mac.FAKE_KEY}'})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            outcome = f'HTTP {response.status}'
    except urllib.error.HTTPError as error:
        outcome = f'HTTP {error.code}（网络已连通）'
    except Exception as error:  # noqa: BLE001 - 记录任何失败
        outcome = f'失败：{error!r}'
    info['system_proxy_client'] = {'proxies_seen': urllib.request.getproxies(), 'result': outcome,
                                   'seconds': round(time.time() - started, 1)}
    started = time.time()
    curl = shutil.which('curl.exe') or 'curl.exe'
    direct = subprocess.run([curl, '-sS', '-o', 'NUL', '-w', '%{http_code}', '--max-time', '20',
                             f'https://{mac.API_HOST}/v1/models'], capture_output=True, text=True)
    info['direct_connection'] = {'result': (direct.stdout + direct.stderr).strip(), 'seconds': round(time.time() - started, 1)}
    report['vpn_simulation'] = info
    print(json.dumps(info, ensure_ascii=False, indent=2), flush=True)
    return proxy_server


def doctor_outside_codex(tool, desktop):
    started = time.time()
    result = subprocess.run([str(tool), 'doctor', '--output-dir', str(desktop)], capture_output=True, text=True,
                            encoding='utf-8', errors='replace', timeout=180)
    return dict(mac.summarize(mac.parse_doctor(result.stdout)), seconds=round(time.time() - started, 1))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tool', help='要验证的生图工具程序，默认已发布的 V0.9.3')
    args = parser.parse_args()
    if sys.platform != 'win32':
        raise SystemExit('需要真实的 Windows')

    work = Path(os.environ.get('RUNNER_TEMP', os.environ.get('TEMP', '.'))) / 'image-rule-repro'
    report_dir = work / 'report'
    report_dir.mkdir(parents=True, exist_ok=True)
    home = Path.home()
    codex_home = home / '.codex'
    if codex_home.exists() and any(codex_home.iterdir()):
        raise SystemExit(f'测试机已有 {codex_home}，不覆盖')
    codex_home.mkdir(parents=True, exist_ok=True)
    desktop = home / 'Desktop'
    desktop.mkdir(exist_ok=True)
    workspace = home / 'repro-work'
    workspace.mkdir(exist_ok=True)

    report = {'system': subprocess.run(['cmd', '/c', 'ver'], capture_output=True, text=True).stdout.strip()}
    backend = install_codex(report)
    tool, skill_command = install_tool(Path(args.tool) if args.tool else RELEASE_TOOL, codex_home, work, report)
    command = f"{skill_command} doctor --output-dir '{desktop}'"
    report['command'] = command
    report['before_vpn_outside_codex'] = doctor_outside_codex(tool, desktop)

    proxy_server = simulate_vpn(report)
    report['vpn_outside_codex'] = doctor_outside_codex(tool, desktop)

    server = mac.serve(mac.MODEL)
    port = server.server_address[1]
    config = ('approval_policy = "on-request"\nsandbox_mode = "workspace-write"\n'
              'windows.sandbox = "unelevated"\n')
    results = []
    for attempt in ['第1次启动', '第2次重新启动']:
        started = time.time()
        result = mac.run_scenario(f'windows-vpn-workspace-write-code-{attempt}', backend, 'gpt-6.1-sol', 'code',
                                  config, command, codex_home, workspace, port, report_dir)
        results.append(dict(result, seconds=round(time.time() - started, 1)))

    proxy_server.shutdown()
    proxy_server.server_close()
    report['vpn_quit_outside_codex'] = doctor_outside_codex(tool, desktop)
    # VPN 改用 PAC（自动代理）模式，然后完全关闭代理：看诊断给出的指导。
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, INTERNET_SETTINGS, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, 'ProxyEnable', 0, winreg.REG_DWORD, 0)
        winreg.SetValueEx(key, 'AutoConfigURL', 0, winreg.REG_SZ, 'http://127.0.0.1:7890/pac')
    report['pac_outside_codex'] = doctor_outside_codex(tool, desktop)
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, INTERNET_SETTINGS, 0, winreg.KEY_SET_VALUE) as key:
        winreg.DeleteValue(key, 'AutoConfigURL')
    report['no_proxy_outside_codex'] = doctor_outside_codex(tool, desktop)
    server.shutdown()
    report['scenarios'] = results
    report['proxy_log'] = mac.PROXY_LOG
    (report_dir / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

    vpn = report['vpn_simulation']
    lines = [
        '## Windows 生图 VPN 复现',
        f"- Codex：`{report['codex']['version']}`；生图工具 SHA-256 `{report['tool']['sha256'][:16]}`；Skill 命令 `{skill_command}`",
        f"- 开 VPN 前在 Codex 外直接运行：`{report['before_vpn_outside_codex'].get('network_detail', '')[:120]}`",
        f"- 模拟 VPN：注册表系统代理 `{vpn['registry']}`；直连解析为 `{vpn['resolved_after']}`",
        f"- 走系统代理的程序（同 ChatGPT）：`{vpn['system_proxy_client']['result']}`，{vpn['system_proxy_client']['seconds']} 秒",
        f"- 不走系统代理的直连：`{vpn['direct_connection']['result'][:100]}`，{vpn['direct_connection']['seconds']} 秒",
        f"- 生图工具在 Codex 外：{report['vpn_outside_codex'].get('seconds')} 秒，`{report['vpn_outside_codex'].get('network_detail', '')[:220]}`",
        f"- VPN 软件退出后诊断：`{report['vpn_quit_outside_codex'].get('network_detail', '')[:400]}`",
        f"- VPN 用 PAC 模式时诊断：`{report['pac_outside_codex'].get('network_detail', '')[:400]}`",
        f"- 没有任何代理时诊断：`{report['no_proxy_outside_codex'].get('network_detail', '')[:400]}`",
    ]
    for item in results:
        lines.append(f"- {item['scenario']}：工具运行 `{item.get('tool_ran')}`，能写桌面 `{item.get('desktop_writable')}`，"
                     f"联网 `{item.get('network_reached')}`，用时 {item.get('seconds')} 秒，诊断说 `{item.get('network_detail', '')[:200]}`")
    summary = '\n'.join(lines) + '\n'
    print(summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
            stream.write(summary)


if __name__ == '__main__':
    main()
