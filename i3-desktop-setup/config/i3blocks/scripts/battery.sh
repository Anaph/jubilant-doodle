#!/usr/bin/env bash
# battery.sh — battery charge for the i3blocks bar (uConsole: AXP228).
# i3blocks protocol: line 1 = full_text, line 2 = short_text, line 3 = colour.
# Colour is level-based here (green/amber/red), overriding the block's color=.

for p in /sys/class/power_supply/*; do
    [ -r "$p/type" ] || continue
    [ "$(cat "$p/type" 2>/dev/null)" = "Battery" ] || continue
    cap="$(cat "$p/capacity" 2>/dev/null)"
    [ -n "$cap" ] || continue
    case "$(cat "$p/status" 2>/dev/null)" in
        Charging) sym="+" ;;
        Discharging) sym="-" ;;
        Full) sym="=" ;;
        *) sym="" ;;
    esac
    if   [ "$cap" -le 15 ]; then col="#f7768e"
    elif [ "$cap" -le 35 ]; then col="#e0af68"
    else col="#9ece6a"
    fi
    printf 'BAT %s%%%s\n' "$cap" "$sym"
    printf 'BAT %s%%\n' "$cap"
    printf '%s\n' "$col"
    exit 0
done

# No battery exposed in /sys/class/power_supply — usually means the ClockworkPi
# kernel/overlay (AXP228 driver) isn't active. Show it so it's not silently gone.
printf 'BAT n/a\n'
printf 'BAT?\n'
printf '#565f89\n'
