"""Shared native launchers; installation source stays in its owning project."""

from __future__ import annotations

import hashlib
import os
import plistlib
import shutil
import subprocess
import zipfile
from pathlib import Path

LAUNCHER_ROOT = Path(__file__).resolve().parent
WORK_ROOT = LAUNCHER_ROOT / ".work"


def build_environment() -> dict[str, str]:
    environment = os.environ.copy()
    for name, directory in {
        "GOCACHE": WORK_ROOT / "go-cache",
        "GOPATH": WORK_ROOT / "go-path",
        "GOTMPDIR": WORK_ROOT / "tmp",
        "TMPDIR": WORK_ROOT / "tmp",
        "XDG_CONFIG_HOME": WORK_ROOT / "config",
        "XDG_CACHE_HOME": WORK_ROOT / "cache",
        "XDG_DATA_HOME": WORK_ROOT / "data",
        "DOTNET_CLI_HOME": WORK_ROOT / "dotnet",
        "TEST_TELEMETRY_DIR": WORK_ROOT / "telemetry",
    }.items():
        directory.mkdir(parents=True, exist_ok=True)
        environment[name] = str(directory)
    (WORK_ROOT / "telemetry/mode").write_text("off\n")
    environment.update({
        "GOTOOLCHAIN": "local", "GOENV": "off", "CGO_ENABLED": "0",
        "GOPROXY": "off", "GOSUMDB": "off",
        "POWERSHELL_TELEMETRY_OPTOUT": "1", "POWERSHELL_UPDATECHECK": "Off",
    })
    return environment


def go_command() -> str:
    command = shutil.which("go")
    if command:
        return command
    existing = Path("/usr/local/go/bin/go")
    if existing.is_file():
        return str(existing)
    raise SystemExit("构建需要本机已有 Go 1.23 或以上版本。")


def build_launcher(system: str, architecture: str) -> Path:
    environment = build_environment()
    environment.update({"GOOS": system, "GOARCH": architecture})
    output = WORK_ROOT / f"launcher-{system}-{architecture}"
    subprocess.run(
        [go_command(), "build", "-trimpath", "-buildvcs=false", "-ldflags=-s -w", "-o", str(output), "."],
        cwd=LAUNCHER_ROOT, env=environment, check=True,
    )
    return output


def powershell_runner(command: str) -> bytes:
    script = """$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
try {
__COMMAND__
    exit 0
} catch {
    [Console]::Error.WriteLine(('执行失败：' + $_.Exception.Message))
    exit 1
}
""".replace("__COMMAND__", command)
    return script.encode("utf-8-sig")


def windows_executable(output: Path, files: dict[str, bytes]) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(build_launcher("windows", "amd64"), output)
    with zipfile.ZipFile(output, "a", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in files.items():
            archive.writestr(name, data)
    output.chmod(0o755)
    return output


TERMINAL_RUNNER = """#!/bin/bash
set -u
resource_dir="$(cd "$(dirname "$0")" && pwd)"
/bin/bash "$resource_dir/install.sh"
result=$?
printf '\\n'
if [ "$result" -ne 0 ]; then
  printf '操作未完成，退出码：%s。请保留上面的错误提示。\\n' "$result"
fi
printf '按回车结束，随后可关闭本窗口。'
IFS= read -r ignored </dev/tty || true
exit "$result"
"""


def mac_application(output: Path, identifier: str, version: str, files: dict[str, bytes]) -> Path:
    contents = output / "Contents"
    resources = contents / "Resources"
    executables = contents / "MacOS"
    resources.mkdir(parents=True, exist_ok=True)
    executables.mkdir(parents=True, exist_ok=True)
    launcher = executables / "launcher"
    shutil.copyfile(build_launcher("darwin", "arm64"), launcher)
    launcher.chmod(0o755)
    for name, data in {"run.command": TERMINAL_RUNNER.encode(), **files}.items():
        destination = resources / name
        destination.write_bytes(data)
        destination.chmod(0o755)
    (contents / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundleDevelopmentRegion": "zh_CN",
        "CFBundleIdentifier": identifier,
        "CFBundleName": output.stem,
        "CFBundleDisplayName": output.stem,
        "CFBundleExecutable": "launcher",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
        "CFBundleSupportedPlatforms": ["MacOSX"],
        "LSMinimumSystemVersion": "12.0",
        "LSUIElement": True,
        "NSAppleEventsUsageDescription": "打开终端，执行你双击的 UseGoodAI 配置或安装工具。",
    }, sort_keys=False))
    (contents / "PkgInfo").write_bytes(b"APPL????")
    return output


def write_checksums(output: Path) -> None:
    paths = sorted(path for path in output.rglob("*") if path.is_file() and path.name != "SHA256SUMS")
    (output / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(output).as_posix()}\n"
        for path in paths
    ), encoding="utf-8")
