#!/usr/bin/env bash
#
# uConsole i3 session hook — deployed by the installer's --uconsole module.
# Rotates the DSI panel to landscape and starts the Bluetooth tray applet.
# ROTATE is substituted at install time (--rotate); empty value = leave as-is.

ROTATE="right"   # right|left|normal|inverted ; empty disables rotation

# --- Panel rotation --------------------------------------------------------
# The uConsole 5" panel is mounted portrait; rotate it to landscape. The DSI
# output is auto-detected so this keeps working if the connector name changes.
if command -v xrandr >/dev/null 2>&1 && [ -n "$ROTATE" ]; then
    out="$(xrandr 2>/dev/null | awk '/ connected/ && $1 ~ /DSI/ {print $1; exit}')"
    [ -z "$out" ] && out="DSI-1"
    xrandr --output "$out" --rotate "$ROTATE" 2>/dev/null || true
fi

# --- Bluetooth tray applet -------------------------------------------------
if command -v blueman-applet >/dev/null 2>&1; then
    pgrep -x blueman-applet >/dev/null 2>&1 || blueman-applet &
fi
