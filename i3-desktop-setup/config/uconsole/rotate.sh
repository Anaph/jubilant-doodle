#!/bin/sh
# uConsole panel rotation, run by LightDM as its display-setup-script so the
# login greeter (and the X session that follows) come up in landscape.
# __ROTATE__ is replaced with the chosen rotation at install time.

out=$(xrandr 2>/dev/null | awk '/ connected/ && $1 ~ /DSI/ {print $1; exit}')
[ -z "$out" ] && out=DSI-1
xrandr --output "$out" --rotate __ROTATE__ 2>/dev/null || true
