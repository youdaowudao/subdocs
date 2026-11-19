"""Build the self-contained PowerShell command and sync its two release copies."""

from argparse import ArgumentParser
from pathlib import Path


PROJECT = Path(__file__).resolve().parent
SOURCE = PROJECT / "windows"
INSTALLER = PROJECT.parent
REPOSITORY = INSTALLER.parent
DESTINATIONS = (
    INSTALLER / "install/chinese.ps1",
    REPOSITORY / "docs/public/install/chinese.ps1",
)
# The wrapper reads the core from disk when run locally; the release embeds it instead.
CORE_READER = (
    "$coreScript = [scriptblock]::Create([IO.File]::ReadAllText("
    "(Join-Path $PSScriptRoot 'Enable-CodexI18nCurrentCache.ps1')))"
)


def source_text(name):
    return (SOURCE / name).read_text(encoding="utf-8-sig").rstrip()


def build():
    wrapper = source_text("Reset-And-Enable-CodexI18nCurrentCache.ps1")
    core = source_text("Enable-CodexI18nCurrentCache.ps1")
    if wrapper.count(CORE_READER) != 1 or "$PSScriptRoot" in core:
        raise SystemExit("入口或核心脚本结构已变化，无法生成独立脚本。")
    body = wrapper.replace(CORE_READER, "$coreScript = {\n" + core + "\n}", 1)
    version = source_text("VERSION")
    license_comment = "\n".join(f"# {line}" if line else "#" for line in source_text("LICENSE").splitlines())
    banner = f"# UseGoodAI Codex 中文化 {version}\n# 由 codex-zh/build.py 生成。\n{license_comment}\n"
    # The HTTP response declares UTF-8. Invoke-RestMethod retains any BOM.
    return (banner + "& {\n" + body + "\n}\n").encode("utf-8")


def main():
    parser = ArgumentParser(description="生成或核对两个 Codex 中文化发布副本。")
    parser.add_argument("--check", action="store_true", help="仅核对当前副本字节")
    args = parser.parse_args()
    artifact = build()
    for path in DESTINATIONS:
        if args.check:
            if not path.exists() or path.read_bytes() != artifact:
                raise SystemExit(f"发布副本与源码不一致：{path.relative_to(REPOSITORY)}")
        else:
            path.write_bytes(artifact)
        print(path.relative_to(REPOSITORY))


if __name__ == "__main__":
    main()
