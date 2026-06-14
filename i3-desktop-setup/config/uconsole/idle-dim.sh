#!/bin/sh
# uconsole-idle-dim — dim the backlight after a period of inactivity and restore
# it on the next activity. The backlight is the biggest idle drain, so this is
# the main lever for lowering idle power without touching the active brightness.
# Skips while the deep-sleep is active (so it doesn't fight uconsole-sleep).

command -v xprintidle >/dev/null 2>&1 || exit 0
command -v brightnessctl >/dev/null 2>&1 || exit 0

IDLE_MS=60000          # dim after 60 s idle
DIM_PCT=10             # dim level (percent)
SLEEP_STATE="${XDG_RUNTIME_DIR:-/tmp}/uconsole-sleep-state"

dimmed=0
saved=""

while sleep 5; do
    # In deep-sleep (power button), leave the backlight to uconsole-sleep.
    [ -s "$SLEEP_STATE" ] && continue

    idle="$(xprintidle 2>/dev/null)" || continue
    case "$idle" in (*[!0-9]*|"") continue;; esac

    if [ "$idle" -ge "$IDLE_MS" ] && [ "$dimmed" -eq 0 ]; then
        saved="$(brightnessctl get 2>/dev/null)"
        brightnessctl set "${DIM_PCT}%" >/dev/null 2>&1
        dimmed=1
    elif [ "$idle" -lt "$IDLE_MS" ] && [ "$dimmed" -eq 1 ]; then
        [ -n "$saved" ] && brightnessctl set "$saved" >/dev/null 2>&1
        dimmed=0
    fi
done
