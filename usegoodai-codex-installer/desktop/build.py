#!/usr/bin/env python3
"""Build tools 1 and 3 of the numbered set, plus the two website downloads.

Tool 1 is the quick-connect assistant: the Windows window from
../quick-connect, and on Mac the terminal .app running install/codex.sh,
which reads a key from the clipboard when started from the .app.
"""

import importlib.util
import shutil
import sys
from pathlib import Path

from packaging import (mac_application, powershell_runner, terminal_runner, windows_executable,
                       write_checksums, zip_application)

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = PROJECT_ROOT / "dist" / "desktop"
WINDOWS = OUTPUT_ROOT / "Windows-x64"
MAC = OUTPUT_ROOT / "Mac-Apple芯片"
DOWNLOAD = OUTPUT_ROOT / "download"

ASSISTANT = "UseGoodAI中转快速接入助手"
ASSISTANT_TOOL = "1." + ASSISTANT
# Same identifier as the former "1.Codex接入配置", so the permission to
# control Terminal carries over.
ASSISTANT_IDENTIFIER = "com.usegoodai.codex-config"
ASSISTANT_VERSION = "1.0.0"
WINDOWS_DOWNLOAD = "usegoodai-quick-connect-windows-x64.exe"
MAC_DOWNLOAD = "usegoodai-quick-connect-mac-arm64.zip"

TERMINAL_TOOLS = (
    ("3.Codex国产模型导入", "codex-models", "com.usegoodai.codex-models"),
)


def load_quick_connect():
    spec = importlib.util.spec_from_file_location("quick_connect_build", PROJECT_ROOT / "quick-connect" / "build.py")
    module = importlib.util.module_from_spec(spec)
    previous = sys.dont_write_bytecode
    sys.dont_write_bytecode = True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous
    return module


def assistant_mac(output: Path) -> Path:
    return mac_application(output, ASSISTANT_IDENTIFIER, ASSISTANT_VERSION, {
        "install.sh": (PROJECT_ROOT / "install" / "codex.sh").read_bytes(),
    }, runner=terminal_runner(" --from-app"))


def main() -> None:
    quick_connect = load_quick_connect()
    if f'Version     = "{ASSISTANT_VERSION}"' not in (PROJECT_ROOT / "quick-connect/connect/product.go").read_text():
        raise SystemExit("Mac 版本号与 quick-connect/connect/product.go 不一致。")
    # Start clean so replaced tools, such as 1.Codex接入配置, do not linger.
    shutil.rmtree(OUTPUT_ROOT, ignore_errors=True)

    quick_connect.build_windows(WINDOWS / f"{ASSISTANT_TOOL}.exe")
    assistant_mac(MAC / f"{ASSISTANT_TOOL}.app")

    for title, script, identifier in TERMINAL_TOOLS:
        powershell = (PROJECT_ROOT / "install" / f"{script}.ps1").read_bytes()
        # Downloaded scripts must also parse correctly in Windows PowerShell 5.1.
        if not powershell.startswith(b"\xef\xbb\xbf"):
            powershell = b"\xef\xbb\xbf" + powershell
        windows_executable(WINDOWS / f"{title}.exe", {
            "start.ps1": powershell_runner("    & (Join-Path $PSScriptRoot 'install.ps1')"),
            "install.ps1": powershell,
        })
        mac_application(MAC / f"{title}.app", identifier, "1.0.0", {
            "install.sh": (PROJECT_ROOT / "install" / f"{script}.sh").read_bytes(),
        })

    # Website downloads keep fixed English names; the site's headers give the
    # Chinese file name. The Mac .app in the zip has no tool number.
    DOWNLOAD.mkdir(parents=True)
    shutil.copyfile(WINDOWS / f"{ASSISTANT_TOOL}.exe", DOWNLOAD / WINDOWS_DOWNLOAD)
    staging = OUTPUT_ROOT / ".download-staging"
    zip_application(assistant_mac(staging / f"{ASSISTANT}.app"), DOWNLOAD / MAC_DOWNLOAD)
    shutil.rmtree(staging)

    write_checksums(OUTPUT_ROOT)
    print(OUTPUT_ROOT)


if __name__ == "__main__":
    main()
