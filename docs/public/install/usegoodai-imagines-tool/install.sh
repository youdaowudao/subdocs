#!/usr/bin/env bash

set -euo pipefail

release_base="https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.2-r3"

if ! command -v curl >/dev/null 2>&1; then
  echo "安装失败：未找到 curl，无法下载安装程序。" >&2
  exit 1
fi

system_name="$(uname -s)"
machine_name="$(uname -m)"
case "$system_name/$machine_name" in
  Darwin/arm64)
    artifact="usegoodai-imagines-tool-v0.2-r3-darwin-arm64"
    expected_sha256="69eaf728fb85c9ba478a4e2c3ce3f294f9795e0f19285ed29e45fa37987a4abf"
    ;;
  *)
    echo "安装失败：V0.2-r3 仅支持 Apple Silicon 64 位 Mac，当前为 $system_name/$machine_name。" >&2
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

echo "正在下载中转站生图工具 V0.2-r3……"
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
"$binary_path" install "$@"
