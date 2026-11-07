#!/bin/bash
# Runs on the macOS machine of GitHub Actions against the built .app: Launch
# Services must pick the app for usegoodai:// links, and the launcher must
# receive the link, answer with the right message and quit by itself.
# Cases that would open Terminal need the "control Terminal" permission and
# are left to the manual check on a real Mac (see ../README.md).
# The synthetic key is generated here and never printed.
set -euo pipefail
export LC_ALL=en_US.UTF-8

app="$(cd "$1" && pwd -P)"
launcher="$app/Contents/MacOS/launcher"
state="$HOME/Library/Caches/com.usegoodai.codex-config"
key="sk-ci$(uuidgen | tr -d '-' | tr 'A-Z' 'a-z')"
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

failures=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

"$lsregister" -f "$app"
handler="$(osascript -l JavaScript -e 'ObjC.import("AppKit"); var u = $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL($.NSURL.URLWithString("usegoodai://import")); u.isNil() ? "" : u.path.js')"
if [ -n "$handler" ] && [ "$(cd "$handler" && pwd -P)" = "$app" ]; then
  pass "usegoodai:// 由本 .app 打开"
else
  fail "usegoodai:// 的处理程序是：$handler"
fi

alert_shown() {
  ps -axww -o command= | grep -F 'display alert' | grep -Fq "$1"
}

# open_link NAME LINK MESSAGE: the launcher shows MESSAGE, then quits.
open_link() {
  local name="$1" link="$2" message="$3" i
  pkill -f 'display alert' 2>/dev/null || true
  open "$link"
  for i in $(seq 1 60); do
    alert_shown "$message" && break
    sleep 0.25
  done
  if alert_shown "$message"; then
    pass "${name}：提示「${message}」"
  else
    fail "${name}：没有出现提示「${message}」"
  fi
  for i in $(seq 1 60); do
    pgrep -f "$launcher" >/dev/null || break
    sleep 0.25
  done
  if pgrep -f "$launcher" >/dev/null; then
    fail "${name}：启动器没有自动退出"
    pkill -f "$launcher" || true
  else
    pass "${name}：启动器已自动退出"
  fi
  pkill -f 'display alert' 2>/dev/null || true
}

open_link "缺少密钥" "usegoodai://import?v=1&app=codex&name=ci" "导入链接不完整，请回网站重新点「一键导入」。"
open_link "带地址参数" "usegoodai://import?v=1&app=codex&key=$key&base_url=https%3A%2F%2Fexample.com" "导入链接不完整，请回网站重新点「一键导入」。"
open_link "版本过高" "usegoodai://import?v=2&app=codex&key=$key" "当前助手不支持这个导入，请下载新版助手。"
open_link "其他应用" "usegoodai://import?v=1&app=gemini&key=$key" "当前助手不支持这个导入，请下载新版助手。"
open_link "Claude 链接" "usegoodai://import?v=1&app=claude&key=$key" "Mac 版助手只能接入 Codex，一键导入 Claude 只有 Windows 版支持。Mac 上请按教程「Claude Desktop 接入」手动配置。"

# A window that is still configuring Codex: a valid link must not start a
# second one, and the key must not be handed over.
work="$(mktemp -d)"
printf 'sleep 120\n' > "$work/run.command"
/bin/bash "$work/run.command" &
holder=$!
mkdir -p "$state/run.lock"
printf '%s\n' "$holder" > "$state/run.lock/pid"
open_link "已有窗口在配置" "usegoodai://import?v=1&app=codex&key=$key&name=ci" "另一个快速接入助手窗口正在配置 Codex。请先在那个终端窗口完成或关闭它，再点一次「一键导入」。"
if ls "$state" | grep -q '^import-'; then
  fail "已有窗口在配置时仍创建了密钥交接文件"
else
  pass "已有窗口在配置时没有交出密钥"
fi
kill "$holder" 2>/dev/null || true
rm -rf "$state/run.lock" "$work"

# 2.UseGoodAI生图工具 runs this script (usegoodai-imagines-tool/appkey_darwin.go,
# whose tests check that both copies match) to see whether the assistant
# macOS opens for usegoodai:// links hands keys over.
assistant_script="$(cat <<'JS'
(function () {
  ObjC.import('AppKit');
  var app = $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL($.NSURL.URLWithString('usegoodai://import'));
  if (app.isNil()) { return ''; }
  var bundle = $.NSBundle.bundleWithURL(app);
  if (bundle.isNil()) { return ''; }
  var identifier = ObjC.unwrap(bundle.bundleIdentifier) || '';
  var version = ObjC.unwrap(bundle.objectForInfoDictionaryKey('CFBundleShortVersionString')) || '';
  return identifier + ' ' + version;
})()
JS
)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
found="$(osascript -l JavaScript -e "$assistant_script" 2>&1 || true)"
if [ "$found" = "com.usegoodai.codex-config $version" ]; then
  pass "生图工具能认出已登记的助手：$found"
else
  fail "生图工具认出的助手是「$found」，应为「com.usegoodai.codex-config $version」"
fi

# While that window waits for a key it reads $state/image-key/key.fifo: an
# app=codex link goes there, not to Codex.
image_dir="$state/image-key"
mkdir -p "$image_dir"
chmod 700 "$state" "$image_dir"
mkfifo -m 600 "$image_dir/key.fifo"
exec 3<>"$image_dir/key.fifo"
open "usegoodai://import?v=1&app=codex&key=$key&name=ci"
handed=""
IFS= read -r -t 15 -u 3 handed || true
if [ "$handed" = "{\"key\":\"$key\",\"name\":\"ci\"}" ]; then
  pass "生图工具窗口在等 Key 时，导入链接交给了它"
else
  fail "生图工具窗口没有收到导入链接的密钥（收到 ${#handed} 个字符）"
fi
for i in $(seq 1 60); do
  pgrep -f "$launcher" >/dev/null || break
  sleep 0.25
done
if pgrep -f "$launcher" >/dev/null; then
  fail "交给生图工具后启动器没有自动退出"
  pkill -f "$launcher" || true
else
  pass "交给生图工具后启动器已自动退出"
fi
if ls "$state" | grep -q '^import-'; then
  fail "交给生图工具时仍去配置了 Codex"
else
  pass "交给生图工具时没有配置 Codex"
fi
exec 3<&-
rm -rf "$image_dir"

osascript -e 'tell application "Terminal" to quit' >/dev/null 2>&1 || true

if [ "$failures" -ne 0 ]; then
  printf '%s 项失败\n' "$failures"
  exit 1
fi
printf '全部通过\n'
