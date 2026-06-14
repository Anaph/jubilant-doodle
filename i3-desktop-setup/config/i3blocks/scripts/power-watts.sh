#!/usr/bin/env bash
# power-watts.sh — battery power (W) for i3blocks.
#   positive "3.0W"  = drawing from the battery (consumption);
#   negative "-5.0W" = charging (battery gaining).
# A stub power_now=0 is skipped (falls through to current*voltage, then a hwmon
# sensor). Prints nothing if no live reading is available.

# emit <watts-magnitude-or-signed> <status>: print "[-]X.XW" if meaningfully >0.
emit() {
    awk -v w="$1" -v st="$2" 'BEGIN{
        a = (w < 0) ? -w : w
        if (a <= 0.05) exit 1
        sign = (st == "Charging") ? "-" : ""
        printf "%s%.1fW\n", sign, a
        exit 0
    }'
}

# 1) battery/PSU: power_now (µW), else current_now*voltage_now (µA*µV). Sign from
#    the same node's charge/discharge status.
for p in /sys/class/power_supply/*; do
    [ -d "$p" ] || continue
    st=$(cat "$p/status" 2>/dev/null)
    uw=$(cat "$p/power_now" 2>/dev/null)
    [ -n "$uw" ] && emit "$(awk -v x="$uw" 'BEGIN{print x/1e6}')" "$st" && exit 0
    i=$(cat "$p/current_now" 2>/dev/null); v=$(cat "$p/voltage_now" 2>/dev/null)
    [ -n "$i" ] && [ -n "$v" ] && \
        emit "$(awk -v i="$i" -v v="$v" 'BEGIN{print (i/1e6)*(v/1e6)}')" "$st" && exit 0
done

# 2) hwmon INA-style sensor (no charge/discharge sign available).
for h in /sys/class/hwmon/*; do
    [ -d "$h" ] || continue
    uw=$(cat "$h/power1_input" 2>/dev/null)
    [ -n "$uw" ] && emit "$(awk -v x="$uw" 'BEGIN{print x/1e6}')" "" && exit 0
    a=$(cat "$h/curr1_input" 2>/dev/null); b=$(cat "$h/in1_input" 2>/dev/null)
    [ -n "$a" ] && [ -n "$b" ] && \
        emit "$(awk -v a="$a" -v b="$b" 'BEGIN{print (a/1e3)*(b/1e3)}')" "" && exit 0
done

exit 0
