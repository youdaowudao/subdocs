#!/usr/bin/env bash

set -euo pipefail

release_revision="V0.7.4"
release_base="https://docs.usegoodai.com/install/usegoodai-imagines-tool/releases/v0.7.4"

if ! command -v curl >/dev/null 2>&1; then
  echo "安装失败：未找到 curl，无法下载安装程序。" >&2
  exit 1
fi

system_name="$(uname -s)"
machine_name="$(uname -m)"
translated="0"
if [[ "$system_name/$machine_name" == "Darwin/x86_64" ]] && command -v sysctl >/dev/null 2>&1; then
  translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || printf '0')"
fi

case "$system_name/$machine_name/$translated" in
  Darwin/arm64/*|Darwin/x86_64/1)
    artifact="usegoodai-imagines-tool-v0.7.4-darwin-arm64"
    expected_sha256="09526786c42304ca94ee5714dc4559e0067ea4dfe4cf5a40ff5da1f8ee6d00d0"
    expected_macho_architecture="arm64"
    ;;
  Darwin/x86_64/*)
    artifact="usegoodai-imagines-tool-v0.7.4-darwin-amd64"
    expected_sha256="78194e15ce00233d94eb5701ed04414b870888e6e9e55001e75c824e1af7f067"
    expected_macho_architecture="x86_64"
    ;;
  *)
    echo "安装失败：V0.7.4 仅支持 Apple Silicon 或 Intel 64 位 Mac，当前为 $system_name/$machine_name。" >&2
    exit 1
    ;;
esac

binary_matches_architecture() {
  local candidate="$1"
  local description
  if ! command -v file >/dev/null 2>&1; then
    return 1
  fi
  description="$(file -b "$candidate" 2>/dev/null || true)"
  case "$expected_macho_architecture" in
    arm64)
      [[ "$description" == *"Mach-O"* && "$description" == *"64-bit"* && "$description" == *"arm64"* && "$description" == *"executable"* ]]
      ;;
    x86_64)
      [[ "$description" == *"Mach-O"* && "$description" == *"64-bit"* && "$description" == *"x86_64"* && "$description" == *"executable"* ]]
      ;;
    *)
      return 1
      ;;
  esac
}

codex_home="${CODEX_HOME:-$HOME/.codex}"
installed_release_path="$codex_home/tools/usegoodai-imagines-tool/RELEASE"
installed_binary_path="$codex_home/tools/usegoodai-imagines-tool/usegoodai-imagines-tool"
if [[ -f "$installed_release_path" ]] && [[ -f "$installed_binary_path" ]] && [[ "$(tr -d '\r\n' < "$installed_release_path")" == "$release_revision" ]] && binary_matches_architecture "$installed_binary_path"; then
  echo "中转站生图工具 $release_revision 已是当前 Mac 架构的最新版，无需下载。"
  exit 0
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/usegoodai-imagines-tool.XXXXXX")"
binary_path="$temporary_root/$artifact"
cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

echo "正在下载中转站生图工具 V0.7.4……"
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
if ! binary_matches_architecture "$binary_path"; then
  echo "安装失败：下载的安装程序与当前 Mac 架构不匹配，已停止安装。" >&2
  exit 1
fi

chmod +x "$binary_path"
if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
  echo "安装失败：未检测到可输入的终端。请在终端中直接运行安装命令。" >&2
  exit 1
fi
"$binary_path" install "$@" </dev/tty
