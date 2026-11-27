#!/usr/bin/env python3
"""Exercise the customer's interactive Shell command using a fake local App and Key."""
import errno
import os
import pathlib
import pty
import select
import signal
import subprocess
import tempfile
import time
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "install" / "antigravity.sh"
PATH_PROMPT = "文件夹路径".encode()
KEY_PROMPT = "请输入 Gemini 分组 API Key：".encode()
KEY = b"sk-fake-visible-key"


def executable(path, content="#!/bin/sh\nexit 0\n"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    path.chmod(0o755)


def app(path):
    executable(path / "antigravity")
    (path / "resources/bin").mkdir(parents=True)
    (path / "resources/app.asar").touch()
    (path / "resources/bin/language_server").touch()


@unittest.skipUnless(os.uname().sysname == "Linux", "Linux official archive layout")
class InputTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name) / "home"
        self.home.mkdir()
        self.bin = pathlib.Path(self.tmp.name) / "bin"
        executable(self.bin / "curl", "#!/bin/sh\nprintf 401\n")
        executable(self.bin / "xdg-user-dir", '#!/bin/sh\nprintf "%s\\n" "$TEST_DOWNLOAD_DIR"\n')
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"),
                        PATH=f"{self.bin}:{os.environ['PATH']}", TEST_DOWNLOAD_DIR=str(self.home / "下载资料"))
        self.env.pop("USEGOODAI_KEY", None)

    def interact(self, manual=None):
        pid, master = pty.fork()
        if pid == 0:
            os.execvpe("bash", ["bash", str(SCRIPT)], self.env)
        output = b""
        waited = False
        deadline = time.monotonic() + 10

        def receive():
            nonlocal output
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([master], [], [], remaining)[0]:
                self.fail(f"timed out; {output!r}")
            try:
                chunk = os.read(master, 4096)
            except OSError as error:
                if error.errno == errno.EIO:
                    return False
                raise
            output += chunk
            return bool(chunk)

        try:
            if manual is not None:
                while PATH_PROMPT not in output:
                    self.assertTrue(receive(), output)
                os.write(master, manual.encode() + b"\n")
            while KEY_PROMPT not in output:
                self.assertTrue(receive(), output)
            if manual is None:
                self.assertNotIn(PATH_PROMPT, output)
            os.write(master, KEY + b"\n")
            while receive():
                pass
            _, status = os.waitpid(pid, 0)
            waited = True
            self.assertEqual(os.waitstatus_to_exitcode(status), 1)
            self.assertIn(KEY, output, "the fake Key must be visible as it is entered")
            self.assertIn(b"HTTP 401", output)
            self.assertFalse((self.home / ".config/UseGoodAI/Antigravity/connection.json").exists())
        finally:
            os.close(master)
            if not waited:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)

    def test_standard_download_extracted_app(self):
        app(self.home / "Downloads/Antigravity-x64")
        self.interact()

    def test_xdg_localized_arm64_download_directory(self):
        app(self.home / "下载资料/Antigravity-arm64")
        self.interact()

    def test_manual_folder_with_spaces_and_tilde_no_recursive_search(self):
        app(self.home / "other/My App")
        self.interact("~/other/My App/")

    def test_direct_executable_and_ide_not_selected(self):
        executable(self.bin / "antigravity")  # a same-named non-App CLI/IDE
        path = self.home / "other/Antigravity-x64"
        app(path)
        self.interact(str(path / "antigravity"))


@unittest.skipUnless(os.uname().sysname == "Linux", "Linux CLI shell setup fixture")
class CLIConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name) / "用户 Home"
        self.home.mkdir()
        self.bin = pathlib.Path(self.tmp.name) / "bin"
        executable(self.bin / "curl", """#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then shift; printf '%s' '{"models":[{"name":"models/gemini-3.8-flash"},{"name":"models/gemini-image"}]}' > "$1"; fi
  shift
done
printf 200
""")
        executable(self.home / ".local/bin/agy", """#!/bin/sh
test "$AGY_LLM_GATEWAY_URL" = https://api.usegoodai.com &&
test "$AGY_LLM_GATEWAY_API_KEY" = sk-fake-visible-key &&
test "$AGY_LLM_GATEWAY_WIRE_PROTOCOL" = genai &&
test "$AGY_LLM_GATEWAY_MODELS" = gemini-3.8-flash && printf 'native-cli-configured\\n'
""")
        self.env = dict(os.environ, HOME=str(self.home), SHELL="/bin/bash", XDG_CONFIG_HOME=str(self.home / ".config"),
                        PATH=f"{self.bin}:{os.environ['PATH']}", USEGOODAI_KEY=KEY.decode())
        for name in ("AGY_LLM_GATEWAY_URL", "AGY_LLM_GATEWAY_API_KEY", "AGY_LLM_GATEWAY_WIRE_PROTOCOL", "AGY_LLM_GATEWAY_MODELS"):
            self.env.pop(name, None)
        self.rc = self.home / ".bashrc"
        self.rc.write_text("# user's shell setup\nexport MY_SETTING=keep\n")
        self.config = self.home / ".config/UseGoodAI/Antigravity"

    def invoke(self, action, expect=0):
        p = subprocess.run(["bash", "-s", "--", action], input=SCRIPT.read_text(), env=self.env,
                           capture_output=True, text=True, timeout=10)
        self.assertEqual(p.returncode, expect, p.stdout + p.stderr)
        return p.stdout + p.stderr

    def test_cli_only_install_repeat_and_restore(self):
        self.config.mkdir(parents=True)
        app_profile = self.config / "connection.json"
        app_profile.write_text("existing App config must be untouched")
        for _ in range(2):
            self.assertIn("运行 agy", self.invoke("cli"))
        self.assertEqual(self.rc.read_text().count("# UseGoodAI Antigravity CLI"), 1)
        self.assertIn("export MY_SETTING=keep", self.rc.read_text())
        env_file = self.config / "cli.env"
        self.assertEqual(env_file.stat().st_mode & 0o777, 0o600)
        p = subprocess.run(["bash", "--noprofile", "--rcfile", str(self.rc), "-i", "-c", "agy"], env=self.env,
                           capture_output=True, text=True, timeout=10)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("native-cli-configured", p.stdout)
        self.invoke("cli-restore")
        self.assertFalse(env_file.exists())
        self.assertNotIn("# UseGoodAI Antigravity CLI", self.rc.read_text())
        self.assertIn("export MY_SETTING=keep", self.rc.read_text())
        self.assertEqual(app_profile.read_text(), "existing App config must be untouched")

    def test_cli_rejects_failed_key_before_writing(self):
        executable(self.bin / "curl", "#!/bin/sh\nprintf 401\n")
        self.assertIn("HTTP 401", self.invoke("cli", expect=1))
        self.assertFalse((self.config / "cli.env").exists())
        self.assertNotIn("UseGoodAI", self.rc.read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
