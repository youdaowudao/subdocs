"""No credentials, real user configuration or client termination is used here."""

from __future__ import annotations

import os
import plistlib
import shlex
import shutil
import struct
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

import packaging

PROJECT_ROOT = Path(__file__).resolve().parents[1]
POWERSHELL = PROJECT_ROOT / "codex-domestic-models/.dev-tools/pwsh/pwsh"


class DesktopPackagingTests(unittest.TestCase):
    def test_powershell_wrapper_preserves_interactive_input_and_reports_failures(self) -> None:
        if not POWERSHELL.is_file():
            self.skipTest("本机未安装开发用 PowerShell")
        with tempfile.TemporaryDirectory(dir=packaging.WORK_ROOT) as temporary:
            root = Path(temporary) / "中文 launcher's $(literal)"
            root.mkdir()
            wrapper = root / "start.ps1"
            wrapper.write_bytes(packaging.powershell_runner("    & (Join-Path $PSScriptRoot 'install.ps1')"))
            installer = root / "install.ps1"
            installer.write_text("$value = Read-Host '输入测试值'\nif ($value -ne 'synthetic-input') { throw 'input-lost' }\nWrite-Host 'fixture-ok'\n", encoding="utf-8-sig")
            environment = packaging.build_environment()
            result = subprocess.run([str(POWERSHELL), "-NoProfile", "-File", str(wrapper)], input="synthetic-input\n", text=True, capture_output=True, env=environment)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("fixture-ok", result.stdout)
            installer.write_text("throw 'fixture-failure'", encoding="utf-8-sig")
            failed = subprocess.run([str(POWERSHELL), "-NoProfile", "-File", str(wrapper)], text=True, capture_output=True, env=environment)
            self.assertEqual(failed.returncode, 1)
            self.assertIn("fixture-failure", failed.stderr)

    def test_terminal_runner_preserves_input_and_failure_status_in_quoted_paths(self) -> None:
        if shutil.which("script") is None:
            self.skipTest("缺少伪终端工具")
        with tempfile.TemporaryDirectory(dir=packaging.WORK_ROOT) as temporary:
            root = Path(temporary) / "中文 launcher's $(literal)"
            root.mkdir()
            (root / "run.command").write_text(packaging.TERMINAL_RUNNER)
            (root / "install.sh").write_text("#!/bin/bash\nIFS= read -r value\n[ \"$value\" = synthetic-input ] || exit 91\nprintf 'fixture-ok\\n'\nexit 7\n")
            result = subprocess.run(
                ["script", "-qefc", "/bin/bash " + shlex.quote(str(root / "run.command")), str(root / "terminal.log")],
                input="synthetic-input\n\n", text=True, capture_output=True, timeout=15,
            )
            self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
            self.assertIn("fixture-ok", result.stdout)
            self.assertIn("退出码：7", result.stdout)
            self.assertIn("按回车结束", result.stdout)

    def test_actual_artifacts_have_correct_architecture_and_original_payloads(self) -> None:
        output = PROJECT_ROOT / "dist/desktop"
        for title, script in (("1.Codex接入配置", "codex"), ("3.Codex国产模型导入", "codex-models")):
            executable = output / "Windows-x64" / f"{title}.exe"
            data = executable.read_bytes()
            self.assertEqual(data[:2], b"MZ")
            pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
            self.assertEqual(data[pe_offset:pe_offset + 4], b"PE\0\0")
            self.assertEqual(struct.unpack_from("<H", data, pe_offset + 4)[0], 0x8664)
            self.assertEqual(struct.unpack_from("<H", data, pe_offset + 24 + 68)[0], 3, "双击必须打开控制台窗口")
            with zipfile.ZipFile(executable) as archive:
                self.assertEqual(set(archive.namelist()), {"start.ps1", "install.ps1"})
                original = (PROJECT_ROOT / "install" / f"{script}.ps1").read_bytes().removeprefix(b"\xef\xbb\xbf")
                self.assertEqual(archive.read("install.ps1").removeprefix(b"\xef\xbb\xbf"), original)
            app = output / "Mac-Apple芯片" / f"{title}.app/Contents"
            info = plistlib.loads((app / "Info.plist").read_bytes())
            self.assertEqual(info["CFBundleDisplayName"], title)
            launcher = app / "MacOS" / info["CFBundleExecutable"]
            self.assertEqual(struct.unpack_from("<II", launcher.read_bytes()), (0xFEEDFACF, 0x0100000C))
            self.assertTrue(os.access(launcher, os.X_OK))
            self.assertEqual((app / "Resources/install.sh").read_bytes(), (PROJECT_ROOT / "install" / f"{script}.sh").read_bytes())


if __name__ == "__main__":
    packaging.WORK_ROOT.mkdir(parents=True, exist_ok=True)
    unittest.main()
