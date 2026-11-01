#!/usr/bin/env python3
"""Build the quick-connect assistant's native programs.

build_windows(): the Windows window (cross-compiled anywhere).
build_mac(): the launcher of the Mac terminal .app (macapp/), which receives
usegoodai:// links through Cocoa and so must be built on a Mac; the
mac-quick-connect GitHub Actions workflow does that.
../desktop/build.py places both into the numbered tool set.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WORK = ROOT / ".work"
BUILD_TAGS = "desktop,production,wv2runtime.browser"
MAC_RUNNER = ROOT / "macapp" / "run.command"
MAX_DOWNLOAD_BYTES = 25 * 1024 * 1024


def go_command() -> str:
    command = shutil.which("go") or "/usr/local/go/bin/go"
    if not Path(command).is_file():
        raise SystemExit("构建需要本机已有 Go 1.25 或以上版本。")
    return command


def environment(**extra: str) -> dict[str, str]:
    """Keep module downloads, caches and temporary files inside .work/."""
    env = os.environ.copy()
    for name, directory in {
        "GOPATH": WORK / "go-path",
        "GOCACHE": WORK / "go-cache",
        "GOTMPDIR": WORK / "tmp",
        "TMPDIR": WORK / "tmp",
        "XDG_CACHE_HOME": WORK / "cache",
        "XDG_CONFIG_HOME": WORK / "config",
    }.items():
        directory.mkdir(parents=True, exist_ok=True)
        env[name] = str(directory)
    env.update({"GOTOOLCHAIN": "local", "GOFLAGS": "-mod=readonly -modcacherw", "CGO_ENABLED": "0", "GOENV": "off"})
    env.update(extra)
    return env


def build_windows(output: Path) -> Path:
    """Write the x64 exe with icon, manifest and version information."""
    go = go_command()
    subprocess.run([go, "run", "./tools/resources", "-icon", "frontend/logo.png", "-out", "rsrc_windows_amd64.syso"],
                   cwd=ROOT, env=environment(), check=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        go, "build", "-trimpath", "-buildvcs=false", "-tags", BUILD_TAGS,
        "-ldflags", "-s -w -H windowsgui", "-o", str(output), ".",
    ], cwd=ROOT, env=environment(GOOS="windows", GOARCH="amd64"), check=True)
    size = output.stat().st_size
    if size > MAX_DOWNLOAD_BYTES:
        raise SystemExit(f"{output.name} 有 {size} 字节，超过文档站 25 MiB 的单文件上限。")
    output.chmod(0o755)
    return output


def build_mac(output: Path) -> Path:
    """Write the arm64 launcher; needs macOS with the Xcode command line tools."""
    if sys.platform != "darwin":
        raise SystemExit("Mac 版启动器用到 Apple 的系统接口，只能在 Mac 上编译；请手动触发 GitHub Actions 的 mac-quick-connect 打包。")
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        go_command(), "build", "-trimpath", "-buildvcs=false", "-ldflags", "-s -w", "-o", str(output), "./macapp",
    ], cwd=ROOT, env=environment(GOOS="darwin", GOARCH="arm64", CGO_ENABLED="1", MACOSX_DEPLOYMENT_TARGET="12.0"), check=True)
    output.chmod(0o755)
    return output


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else WORK / "usegoodai-quick-connect-windows-x64.exe"
    print(build_windows(target.resolve()))
