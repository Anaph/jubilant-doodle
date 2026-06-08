#!/usr/bin/env bash
# battery.sh — battery charge for i3blocks. Scans /sys/class/power_supply for a
# real battery (finds the uConsole's axp20x-battery, which i3status' battery
# module misses). i3blocks protocol: line1=full_text, line2=short, line3=colour.

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

# No battery node — usually means the ClockworkPi kernel/overlay (AXP228 driver)
# isn't active. Show it rather than silently hiding.
printf 'BAT n/a\n'
printf 'BAT?\n'
printf '#7982a9\n'
