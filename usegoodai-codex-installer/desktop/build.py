#!/usr/bin/env python3
"""Build the two configuration tools from the original project scripts."""

from pathlib import Path

from packaging import mac_application, powershell_runner, windows_executable, write_checksums

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = PROJECT_ROOT / "dist" / "desktop"
TOOLS = (
    ("1.Codex接入配置", "codex", "com.usegoodai.codex-config"),
    ("3.Codex国产模型导入", "codex-models", "com.usegoodai.codex-models"),
)


def main() -> None:
    for title, script, identifier in TOOLS:
        powershell = (PROJECT_ROOT / "install" / f"{script}.ps1").read_bytes()
        # Downloaded scripts must also parse correctly in Windows PowerShell 5.1.
        if not powershell.startswith(b"\xef\xbb\xbf"):
            powershell = b"\xef\xbb\xbf" + powershell
        windows_executable(OUTPUT_ROOT / "Windows-x64" / f"{title}.exe", {
            "start.ps1": powershell_runner("    & (Join-Path $PSScriptRoot 'install.ps1')"),
            "install.ps1": powershell,
        })
        mac_application(OUTPUT_ROOT / "Mac-Apple芯片" / f"{title}.app", identifier, "1.0.0", {
            "install.sh": (PROJECT_ROOT / "install" / f"{script}.sh").read_bytes(),
        })
    write_checksums(OUTPUT_ROOT)
    print(OUTPUT_ROOT)


if __name__ == "__main__":
    main()
