#!/bin/bash
set -euo pipefail
wid=""
for i in $(seq 1 90); do
  wid=$(xdotool search --onlyvisible --name '^Antigravity$' 2>/dev/null | tail -1 || true)
  [ -n "$wid" ] && break
  sleep 1
done
[ -n "$wid" ] || { echo 'No visible Antigravity window'; exit 1; }
xdotool windowactivate --sync "$wid" || xdotool windowfocus --sync "$wid"
sleep 6
eval "$(xdotool getwindowgeometry --shell "$wid")"
import -window root "$AGY_TEST_EVIDENCE/before.png" || true
xdotool mousemove --window "$wid" "$((WIDTH * 55 / 100))" "$((HEIGHT - 90))" click 1
xdotool type --clearmodifiers test
xdotool key --clearmodifiers Return
sleep 8
import -window root "$AGY_TEST_EVIDENCE/after.png" || true
xdotool key --clearmodifiers alt+F4 || true
