#!/usr/bin/env bash

set -euo pipefail

package_url="https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.2-r1/usegoodai-imagines-tool-v0.2-r1.zip"
package_sha256="ff8bf231c6a2ef5b157413bafb4312ef2bff5ec6fc6e44b83ab395650bd883e5"
package_root_name="usegoodai-imagines-tool-v0.2-r1"

if ! command -v curl >/dev/null 2>&1; then
  echo "安装失败：未找到 curl，无法下载安装包。" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "安装失败：未找到 Python 3。请先安装 Python 3，再重新运行安装命令。" >&2
  exit 1
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/usegoodai-imagines-tool.XXXXXX")"
archive_path="$temporary_root/package.zip"
unpack_path="$temporary_root/unpacked"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

echo "正在下载中转站生图工具 V0.2-r1……"
curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 \
  "$package_url" --output "$archive_path"

python3 - "$archive_path" "$package_sha256" "$unpack_path" <<'PY'
import hashlib
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath

archive_path = Path(sys.argv[1])
expected_hash = sys.argv[2]
unpack_path = Path(sys.argv[3])

digest = hashlib.sha256()
with archive_path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        digest.update(chunk)

if digest.hexdigest() != expected_hash:
    raise SystemExit("安装失败：安装包 SHA-256 校验不通过，已停止安装。")

with zipfile.ZipFile(archive_path) as archive:
    for member in archive.infolist():
        member_path = PurePosixPath(member.filename)
        mode = member.external_attr >> 16
        if member_path.is_absolute() or ".." in member_path.parts:
            raise SystemExit("安装失败：安装包内包含不安全路径，已停止安装。")
        if stat.S_ISLNK(mode):
            raise SystemExit("安装失败：安装包内包含符号链接，已停止安装。")
    archive.extractall(unpack_path)
PY

installer_path="$unpack_path/$package_root_name/installer/install.sh"
if [[ ! -f "$installer_path" ]]; then
  echo "安装失败：安装包内缺少安装入口。" >&2
  exit 1
fi

bash "$installer_path" "$@"
