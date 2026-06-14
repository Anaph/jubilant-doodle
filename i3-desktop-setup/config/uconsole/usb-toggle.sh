#!/bin/sh
# uconsole-usb-toggle — power the AIO USB rail (the 4G dongle / USB-A ports)
# off/on. Bound to a key in i3. Powering the dongle off lets the USB controller
# and CPU reach deep idle — the main idle-power win on the uConsole.

command -v aiov2_ctl >/dev/null 2>&1 || { command -v notify-send >/dev/null 2>&1 && notify-send "aiov2_ctl not installed"; exit 0; }

STATE="${XDG_RUNTIME_DIR:-/tmp}/uconsole-usb-off"
note() { command -v notify-send >/dev/null 2>&1 && notify-send "$1"; }

if [ -f "$STATE" ]; then
    aiov2_ctl USB on >/dev/null 2>&1
    rm -f "$STATE"
    note "USB / 4G rail: ON"
else
    aiov2_ctl USB off >/dev/null 2>&1
    : >"$STATE"
    note "USB / 4G rail: OFF (power saving)"
fi
