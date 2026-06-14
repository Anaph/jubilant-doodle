#!/usr/bin/env bash
# power-watts.sh — instantaneous device power draw in watts for i3blocks.
# Read from the battery: power_now (µW) if present, else current_now * voltage_now
# (µA * µV). The whole device runs off the battery, so this is total consumption.
# Prints nothing if no battery telemetry is exposed.

for p in /sys/class/power_supply/*; do
    [ -r "$p/type" ] || continue
    [ "$(cat "$p/type" 2>/dev/null)" = "Battery" ] || continue

    if [ -r "$p/power_now" ]; then
        uw="$(cat "$p/power_now" 2>/dev/null)"
        [ -n "$uw" ] && awk -v x="$uw" 'BEGIN{x=(x<0)?-x:x; printf "%.1fW\n", x/1000000}'
        exit 0
    fi
    if [ -r "$p/current_now" ] && [ -r "$p/voltage_now" ]; then
        i="$(cat "$p/current_now" 2>/dev/null)"
        v="$(cat "$p/voltage_now" 2>/dev/null)"
        [ -n "$i" ] && [ -n "$v" ] && \
            awk -v i="$i" -v v="$v" 'BEGIN{w=(i/1000000)*(v/1000000); if(w<0)w=-w; printf "%.1fW\n", w}'
        exit 0
    fi
done
