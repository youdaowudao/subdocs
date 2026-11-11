#!/usr/bin/env python3
"""Run published native programs and installer entries, without real credentials.

Only release downloads are simulated. All file writes and native installers run
on the host OS. This does not test paid image calls or desktop authorization.
"""
from __future__ import annotations

import functools
import hashlib
import http.server
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "docs/public/install/usegoodai-imagines-tool"
CURRENT = json.loads((PUBLIC / "latest.json").read_text())['version']
PREVIOUS = "0.9.3"
SYSTEM = {"Windows": "windows", "Darwin": "darwin", "Linux": "linux"}[platform.system()]
ARCH = "arm64" if platform.machine().lower() in ("arm64", "aarch64") else "amd64"
SUFFIX = ".exe" if SYSTEM == "windows" else ""


def program(version: str) -> Path:
    return PUBLIC / f"releases/v{version}/usegoodai-imagines-tool-v{version}-{SYSTEM}-{ARCH}{SUFFIX}"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


def run(command, env, *, input="", success=True):
    options = {} if SYSTEM == "windows" else {"start_new_session": True}
    result = subprocess.run(command, input=input, text=True, encoding="utf-8", errors="replace",
                            capture_output=True, env=env, timeout=60, **options)
    output = result.stdout + result.stderr
    assert (result.returncode == 0) == success, f"exit={result.returncode}: {output}"
    return output


def snapshot(home: Path):
    return {str(p.relative_to(home)): p.read_bytes() for p in home.rglob("*") if p.is_file()}


def check_key(path, before):
    assert (path.read_bytes() if path.exists() else None) == before, "saved key changed"


def main():
    candidate, previous = program(CURRENT), program(PREVIOUS)
    assert candidate.is_file() and previous.is_file()
    candidate.chmod(0o755)
    previous.chmod(0o755)
    report = {"version": 1, "platform": f"{SYSTEM}/{ARCH}", "candidate": CURRENT,
              "candidate_sha256": digest(candidate), "previous": PREVIOUS,
              "previous_sha256": digest(previous), "scenarios": [],
              "scope": "实际原生程序和公开安装入口；仅下载替换为本地模拟，不使用真实 Key",
              "unverified": ["真实鉴权、计费和生图", "Mac 首次授权及 Codex 完整桌面任务"]}
    with tempfile.TemporaryDirectory(prefix="image-upgrade-") as temporary:
        work = Path(temporary)
        served = work / "downloads"
        served.mkdir()
        payload = served / candidate.name
        shutil.copyfile(candidate, payload)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=str(served)))
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            env = dict(os.environ)
            if SYSTEM == "windows":
                # PS 5.1 reads a local Chinese script as UTF-8 only with a BOM.
                # Keep production hash checks and logic; change the download endpoint only.
                script = (PUBLIC / "install.ps1").read_text(encoding="utf-8-sig")
                old = f'https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v{CURRENT}'
                assert script.count(old) == 1
                script = script.replace(old, f"http://127.0.0.1:{server.server_port}")
                entry = work / "安装入口.ps1"
                entry.write_text("[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding\n" + script, encoding="utf-8-sig")
                shell = shutil.which("powershell.exe")
                assert shell, "Windows PowerShell 5.1 missing"
                shell_version = run([shell, "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"], env).strip()
                assert shell_version.startswith("5.1"), shell_version
                entry_command = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(entry)]
            else:
                shell = "/bin/bash"
                shell_version = run([shell, "--version"], env).splitlines()[0]
                if SYSTEM == "darwin":
                    assert "version 3.2" in shell_version, shell_version
                mock_bin = work / "bin"
                mock_bin.mkdir()
                curl = mock_bin / "curl"
                curl.write_text('#!/bin/bash\nwhile [ "$#" -gt 0 ]; do\n  if [ "$1" = --output ]; then cp "$TEST_PAYLOAD" "$2"; exit $?; fi\n  shift\ndone\nexit 91\n')
                curl.chmod(0o755)
                env.update(PATH=str(mock_bin) + os.pathsep + env["PATH"], TEST_PAYLOAD=str(payload))
                entry_command = [shell, str(PUBLIC / "install.sh")]
            report["shell"] = shell_version

            for state in ("saved", "missing", "empty", "whitespace"):
                home = work / f"中文 空格 {state}"
                env["CODEX_HOME"] = str(home)
                home.mkdir()
                unrelated = {"config.toml": b'model = "test-existing-model"\n',
                             "auth.json": b'{"OPENAI_API_KEY":"synthetic-codex-key"}\n'}
                for name, contents in unrelated.items():
                    (home / name).write_bytes(contents)
                run([str(previous), "install", "--key-stdin"], env, input="synthetic-image-key\n")
                tool = home / "tools/usegoodai-imagines-tool"
                key = tool / "api-key"
                if state == "missing":
                    key.unlink()
                elif state == "empty":
                    key.write_bytes(b"")
                elif state == "whitespace":
                    key.write_bytes(b" \n\t")
                before = key.read_bytes() if key.exists() else None

                # A corrupted download must leave the old installation intact.
                original = snapshot(home)
                payload.write_bytes(b"corrupt-download")
                failed = run(entry_command, env, success=False)
                assert "SHA-256" in failed, failed
                assert snapshot(home) == original, "failed download changed installed files"
                shutil.copyfile(candidate, payload)

                output = run(entry_command, env)
                assert f"V{PREVIOUS}" in output and f"V{CURRENT}" in output, output
                assert "请输入专门画图分组 Key" not in output and "Key 不能为空" not in output, output
                manifest = json.loads((tool / "install-manifest.json").read_text())
                assert manifest["version"] == CURRENT
                installed = tool / f"usegoodai-imagines-tool{SUFFIX}"
                assert digest(installed) == digest(candidate)
                check_key(key, before)
                for name, contents in unrelated.items():
                    assert (home / name).read_bytes() == contents, f"{name} changed"

                # Same-version entry uses the cached verified native program.
                payload.unlink()
                repeated = run(entry_command, env)
                assert "无需下载" in repeated and "请输入专门画图分组 Key" not in repeated, repeated
                check_key(key, before)
                shutil.copyfile(candidate, payload)
                report["scenarios"].append({"key": state, "old_version_display": "passed",
                                             "corrupt_download_rollback_and_retry": "passed",
                                             "upgrade_without_input": "passed", "cached_repeat": "passed",
                                             "key_and_unrelated_config_preserved": "passed"})

            # First install asks at most once. Empty input never loops or fails.
            env["CODEX_HOME"] = str(work / "首次 空输入")
            output = run([str(candidate), "install"], env, input="\n\n\n")
            assert output.count("请输入专门画图分组 Key") == 1, output
            assert "Key 不能为空" not in output, output
            assert not (Path(env["CODEX_HOME"]) / "tools/usegoodai-imagines-tool/api-key").exists()
            report["first_install_empty_input"] = "passed: prompts once, installs without a key"
        finally:
            server.shutdown()
            server.server_close()
    output = ROOT / "test-results/image-upgrade-native.json"
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # Windows PowerShell 5.1 can pipe stdout using the legacy code page.
    # The artifact remains UTF-8; console JSON stays encodable everywhere.
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
