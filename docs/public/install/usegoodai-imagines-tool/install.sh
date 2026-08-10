#!/usr/bin/env bash

set -euo pipefail

release_base="https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.3-r3"

if ! command -v curl >/dev/null 2>&1; then
  echo "安装失败：未找到 curl，无法下载安装程序。" >&2
  exit 1
fi

system_name="$(uname -s)"
machine_name="$(uname -m)"
case "$system_name/$machine_name" in
  Darwin/arm64)
    artifact="usegoodai-imagines-tool-v0.3-r3-darwin-arm64"
    expected_sha256="ab7f256fd1c7162a934c5c86b923710178d196a45b6ea42b129592c649a9d178"
    ;;
  *)
    echo "安装失败：V0.3-r3 仅支持 Apple Silicon 64 位 Mac，当前为 $system_name/$machine_name。" >&2
    exit 1
    ;;
esac

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/usegoodai-imagines-tool.XXXXXX")"
binary_path="$temporary_root/$artifact"
cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

echo "正在下载中转站生图工具 V0.3-r3……"
curl --fail --location --progress-bar --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 \
  "$release_base/$artifact" --output "$binary_path"

if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256="$(sha256sum "$binary_path" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  actual_sha256="$(shasum -a 256 "$binary_path" | awk '{print $1}')"
elif command -v openssl >/dev/null 2>&1; then
  actual_sha256="$(openssl dgst -sha256 "$binary_path" | awk '{print $NF}')"
else
  echo "安装失败：未找到 SHA-256 校验工具，已停止安装。" >&2
  exit 1
fi
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "安装失败：安装程序 SHA-256 校验不通过，已停止安装。" >&2
  exit 1
fi

chmod +x "$binary_path"
if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
  echo "安装失败：未检测到可输入的终端。请在终端中直接运行安装命令。" >&2
  exit 1
fi
"$binary_path" install "$@" </dev/tty
