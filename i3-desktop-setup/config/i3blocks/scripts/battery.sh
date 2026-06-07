#!/usr/bin/env bash
# battery.sh — first real battery's charge + status (uConsole: AXP228).
for p in /sys/class/power_supply/*; do
    [ -r "$p/type" ] || continue
    [ "$(cat "$p/type")" = "Battery" ] || continue
    cap="$(cat "$p/capacity" 2>/dev/null)"
    [ -n "$cap" ] || continue
    case "$(cat "$p/status" 2>/dev/null)" in
        Charging) s="+" ;;
        Discharging) s="-" ;;
        Full) s="=" ;;
        *) s="" ;;
    esac
    printf 'bat %s%%%s\n' "$cap" "$s"
    exit 0
done
exit 0
