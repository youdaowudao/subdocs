#!/usr/bin/env python3
"""给 zip 里的每个 Mac App 整体做临时签名（ad-hoc），写出新的 zip。只能在 macOS 上运行。

App 里的程序只有编译器自动加的临时签名、App 整体没有签名时，macOS 判定签名无效
（code has no resources but signature indicates they must be present）；经浏览器下载、
带隔离标记后，双击提示“已损坏，无法打开”，且没有「仍要打开」入口。整体签名后提示变为
“无法验证”，用户可在「系统设置 → 隐私与安全性」点「仍要打开」。没有开发者证书，仍需用户放行一次。

用法：python3 sign_mac.py 输入.zip 输出.zip
原有条目的顺序、时间、权限保持不变；签名产生的 _CodeSignature 目录追加在后面。
"""

import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

FIXED = (1980, 1, 1, 0, 0, 0)


def top_level_apps(root: Path) -> list[Path]:
    return sorted(path for path in root.rglob('*.app')
                  if path.is_dir() and not any(parent.suffix == '.app' for parent in path.parents))


def sign(source: Path, target: Path) -> list[str]:
    if sys.platform != 'darwin':
        raise SystemExit('Mac App 签名只能在 macOS 上用系统自带的 codesign 完成。')
    work = Path(tempfile.mkdtemp(prefix='sign-mac-'))
    subprocess.run(['/usr/bin/ditto', '-x', '-k', str(source), str(work)], check=True)
    apps = top_level_apps(work)
    if not apps:
        raise SystemExit(f'{source} 里没有 Mac App。')
    for app in apps:
        subprocess.run(['/usr/bin/codesign', '--force', '--deep', '--sign', '-', '--timestamp=none', str(app)], check=True)
        subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)

    original = zipfile.ZipFile(source)
    written = set()
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, 'w') as output:
        for info in original.infolist():
            entry = zipfile.ZipInfo(info.filename, info.date_time)
            entry.external_attr = info.external_attr
            entry.compress_type = info.compress_type
            output.writestr(entry, b'' if info.is_dir() else (work / info.filename).read_bytes())
            written.add(info.filename)
        for app in apps:
            for path in sorted(app.rglob('*')):
                name = path.relative_to(work).as_posix() + ('/' if path.is_dir() else '')
                if name in written:
                    continue
                entry = zipfile.ZipInfo(name, FIXED)
                if path.is_dir():
                    entry.external_attr = (stat.S_IFDIR | 0o755) << 16
                    output.writestr(entry, b'')
                else:
                    entry.external_attr = (stat.S_IFREG | 0o644) << 16
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    output.writestr(entry, path.read_bytes())
    return [app.relative_to(work).as_posix() for app in apps]


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('用法：python3 sign_mac.py 输入.zip 输出.zip')
    for name in sign(Path(sys.argv[1]), Path(sys.argv[2])):
        print('已签名：' + name)
