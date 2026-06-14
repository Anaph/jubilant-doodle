#!/bin/sh
# uconsole-bl-toggle — toggle the panel backlight off/on ("sleep" on the
# uConsole). Bound to the power button (XF86PowerOff) in i3: one press turns the
# backlight off, the next restores the previous level. Uses brightnessctl
# (sysfs backlight) because DPMS does not power the DSI panel's backlight.

STATE="${XDG_RUNTIME_DIR:-/tmp}/uconsole-bl-saved"

command -v brightnessctl >/dev/null 2>&1 || exit 0

if [ -s "$STATE" ]; then
    # A saved level exists -> we are "asleep" -> wake: restore it.
    brightnessctl set "$(cat "$STATE")" >/dev/null 2>&1
    : >"$STATE"
else
    # Awake -> sleep: remember the current level and turn the backlight off.
    cur="$(brightnessctl get 2>/dev/null)"
    printf '%s\n' "${cur:-50%}" >"$STATE"
    brightnessctl set 0 >/dev/null 2>&1
fi
