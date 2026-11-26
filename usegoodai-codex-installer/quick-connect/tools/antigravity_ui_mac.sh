#!/bin/bash
set -euo pipefail
for i in $(seq 1 60); do
  if ps -p "$AGY_TEST_PID" >/dev/null && osascript -e 'tell application "System Events" to exists process "Antigravity"' 2>/dev/null | grep -qx true; then break; fi
  sleep 1
done
sleep 6
/usr/sbin/screencapture -x "$AGY_TEST_EVIDENCE/before.png" || true
# No accessibility permission bypass: report the runner limitation if denied.
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Antigravity"
    set frontmost to true
    delay 1
    keystroke "test"
    key code 36
  end tell
end tell
APPLESCRIPT
sleep 8
/usr/sbin/screencapture -x "$AGY_TEST_EVIDENCE/after.png" || true
osascript -e 'tell application "System Events" to keystroke "q" using command down' || true
