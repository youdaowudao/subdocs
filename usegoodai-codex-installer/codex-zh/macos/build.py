"""Build the single-file macOS Chinese UI command and verify both release copies."""

from argparse import ArgumentParser
from pathlib import Path
import re

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parent
INSTALLER = PROJECT.parent
REPOSITORY = INSTALLER.parent
DESTINATIONS = (INSTALLER / "install/chinese.sh", REPOSITORY / "docs/public/install/chinese.sh")
MARKER = "USEGOODAI_CODEX_CHINESE_PYTHON"


def build():
    header = (SOURCE / "launcher.sh").read_text(encoding="utf-8").rstrip()
    version = (SOURCE / "VERSION").read_text().strip()
    license_lines = (SOURCE / "LICENSE").read_text().splitlines()
    notice = "\n".join(f"# {line}" if line else "#" for line in license_lines)
    # UseGoodAI：从 Windows current-key 源码原样提取，单文件内嵌，不增加运行时下载。
    windows = (PROJECT / "windows/Enable-CodexI18nCurrentCache.ps1").read_text(encoding="utf-8")
    expressions = {
        "EXPRESSION": re.search(r"\$pageExpression = @'\n(.*?)\n'@", windows, re.S)[1],
        "VERIFY_EXPRESSION": re.search(r'\$verifyExpression = @"\n(.*?)\n"@', windows, re.S)[1],
        "SNAPSHOT_EXPRESSION": re.search(r"\$snapshotExpression = @'\n(.*?)\n'@", windows, re.S)[1],
    }
    program = (SOURCE / "chinese.py").read_text(encoding="utf-8").rstrip()
    for name, expression in expressions.items():
        placeholder = f'{name} = ""'
        if program.splitlines().count(placeholder) != 1 or MARKER in program or MARKER in expression:
            raise SystemExit("找不到嵌入缓存脚本的位置。")
        program = re.sub(r"^" + placeholder + r"$", lambda _: f"{name} = {expression!r}", program, count=1, flags=re.M)
    first, body = header.split("\n", 1)
    return f"{first}\n# UseGoodAI Codex 中文化 Mac {version}\n{notice}\n{body} <<'{MARKER}'\n{program}\n{MARKER}\n".encode("utf-8")


def main():
    parser = ArgumentParser(description="生成或核对 Mac Codex 中文化发布脚本。")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = build()
    for path in DESTINATIONS:
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                raise SystemExit(f"发布副本与源码不一致：{path.relative_to(REPOSITORY)}")
        else:
            path.write_bytes(data)
        print(path.relative_to(REPOSITORY))


if __name__ == "__main__":
    main()
