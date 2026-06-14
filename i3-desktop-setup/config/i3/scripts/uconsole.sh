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
# The backlight is the biggest battery drain, so dim a little at start and let
# DPMS blank the screen on idle (lock on blank via xss-lock).
command -v brightnessctl >/dev/null 2>&1 && brightnessctl set 60% >/dev/null 2>&1
if command -v xset >/dev/null 2>&1; then
    xset +dpms 2>/dev/null || true
    xset s 300 300 2>/dev/null || true     # screensaver after 5 min
    xset dpms 0 0 300 2>/dev/null || true   # display off after 5 min idle
fi
# The locker also forces the backlight off, so a short power-button press
# (logind HandlePowerKey=lock) acts as "sleep": screen off + locked.
if command -v xss-lock >/dev/null 2>&1; then
    pgrep -x xss-lock >/dev/null 2>&1 || \
        xss-lock -- sh -c 'xset dpms force off; exec i3lock -n -c 15161e' &
fi

# --- Bluetooth tray applet -------------------------------------------------
if command -v blueman-applet >/dev/null 2>&1; then
    pgrep -x blueman-applet >/dev/null 2>&1 || blueman-applet &
fi

# --- AIO v2 control tray (HackerGadgets), if installed ---------------------
if command -v aiov2_ctl >/dev/null 2>&1; then
    pgrep -f 'aiov2_ctl .*--gui' >/dev/null 2>&1 || aiov2_ctl --gui &
fi
