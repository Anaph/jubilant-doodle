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

# --- Power saving ----------------------------------------------------------
# Start a bit dimmer (the backlight is the biggest drain). "Sleep" is the power
# button: XF86PowerOff -> uconsole-bl-toggle (set up in the i3 config), which
# toggles the backlight via brightnessctl — DPMS does not power the DSI panel.
command -v brightnessctl >/dev/null 2>&1 && brightnessctl set 60% >/dev/null 2>&1

# --- Bluetooth tray applet -------------------------------------------------
if command -v blueman-applet >/dev/null 2>&1; then
    pgrep -x blueman-applet >/dev/null 2>&1 || blueman-applet &
fi

# --- AIO v2 control tray (HackerGadgets), if installed ---------------------
if command -v aiov2_ctl >/dev/null 2>&1; then
    pgrep -f 'aiov2_ctl .*--gui' >/dev/null 2>&1 || aiov2_ctl --gui &
fi
