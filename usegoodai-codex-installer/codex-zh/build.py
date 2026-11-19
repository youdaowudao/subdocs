"""Build the self-contained PowerShell command and sync its two release copies."""

from argparse import ArgumentParser
from pathlib import Path


SOURCE = Path(__file__).resolve().parent
INSTALLER = SOURCE.parent
REPOSITORY = INSTALLER.parent
DESTINATIONS = (
    INSTALLER / "install/chinese.ps1",
    REPOSITORY / "docs/public/install/chinese.ps1",
)


def source_text(name):
    return (SOURCE / name).read_text(encoding="utf-8-sig").rstrip()


def build():
    entry = source_text("chinese.ps1")
    imports = "\n".join(
        f". (Join-Path $PSScriptRoot '{name}')"
        for name in ("desktop.ps1", "config.ps1", "core.ps1")
    )
    parts = [source_text("desktop.ps1"), source_text("config.ps1")]
    core = source_text("core.ps1")
    cache_reader = "    $expressionSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'language-cache.js'))"
    cache_js = source_text("language-cache.js")
    if entry.count(imports) != 1 or core.count(cache_reader) != 1 or "\n'@" in cache_js:
        raise SystemExit("入口或缓存源码结构已变化，无法生成独立脚本。")
    parts.append(core.replace(cache_reader, "    $expressionSource = @'\n" + cache_js + "\n'@", 1))
    effect = entry.replace(imports, "\n\n".join(parts), 1)
    version = source_text("VERSION")
    license_comment = "\n".join(f"# {line}" if line else "#" for line in source_text("LICENSE").splitlines())
    banner = f"# UseGoodAI Codex 中文化 {version}\n# 由 codex-zh/build.py 生成。\n{license_comment}\n"
    return (banner + effect + "\n").encode("utf-8-sig")


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
