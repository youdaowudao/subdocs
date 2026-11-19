"""Build the single-file macOS Chinese UI command and verify both release copies."""

from argparse import ArgumentParser
from pathlib import Path

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
    cache = (PROJECT / "language-cache.js").read_text(encoding="utf-8").rstrip()
    program = (SOURCE / "chinese.py").read_text(encoding="utf-8").rstrip()
    placeholder = 'CACHE_EXPRESSION = ""'
    if program.count(placeholder) != 1 or MARKER in program or MARKER in cache:
        raise SystemExit("找不到嵌入缓存脚本的位置。")
    program = program.replace(placeholder, f"CACHE_EXPRESSION = {cache!r}", 1)
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
