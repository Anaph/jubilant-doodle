#!/bin/sh
# uconsole-sleep — deep power-saving toggle for the uConsole, bound to the power
# button (XF86PowerOff in i3). This is NOT a real suspend (the CM5 has none); the
# system keeps running but is minimised, so it wakes instantly on the next press.
#
#   SLEEP: backlight off, CPU -> powersave, Wi-Fi + NetworkManager off, AIO USB
#          rail off.
#   WAKE : restore all of the above.
#
# Privileged parts (governor, radios, network) run via a narrow sudo NOPASSWD on
# /usr/local/bin/uconsole-powersave.

STATE="${XDG_RUNTIME_DIR:-/tmp}/uconsole-sleep-state"
has() { command -v "$1" >/dev/null 2>&1; }

if [ -s "$STATE" ]; then
    # ---- WAKE ----
    has brightnessctl && brightnessctl set "$(cat "$STATE")" >/dev/null 2>&1
    : >"$STATE"
    has aiov2_ctl && aiov2_ctl USB on >/dev/null 2>&1
    sudo -n /usr/local/bin/uconsole-powersave wake >/dev/null 2>&1
else
    # ---- SLEEP ----
    if has brightnessctl; then brightnessctl get 2>/dev/null >"$STATE"; fi
    [ -s "$STATE" ] || echo 50% >"$STATE"
    sudo -n /usr/local/bin/uconsole-powersave sleep >/dev/null 2>&1
    has aiov2_ctl && aiov2_ctl USB off >/dev/null 2>&1
    has brightnessctl && brightnessctl set 0 >/dev/null 2>&1
fi
