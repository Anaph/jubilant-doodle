#!/usr/bin/env bash
# power-watts.sh — instantaneous device power draw (W) for i3blocks. Tries
# several sources and takes the first NON-zero reading (a stub power_now=0 is
# skipped so it falls through to current*voltage / a hwmon sensor). Prints
# nothing if no live power reading is available — so the block hides rather than
# showing a misleading 0.

# show <watts>: print "X.XW" and succeed if the value is meaningfully > 0.
show() {
    awk -v w="$1" 'BEGIN{ w=(w<0)?-w:w; if (w>0.05){ printf "%.1fW\n", w; exit 0 } exit 1 }'
}

# 1) power_supply: power_now (µW), else current_now*voltage_now (µA*µV).
for p in /sys/class/power_supply/*; do
    [ -d "$p" ] || continue
    uw=$(cat "$p/power_now" 2>/dev/null)
    [ -n "$uw" ] && show "$(awk -v x="$uw" 'BEGIN{print x/1e6}')" && exit 0
    i=$(cat "$p/current_now" 2>/dev/null); v=$(cat "$p/voltage_now" 2>/dev/null)
    [ -n "$i" ] && [ -n "$v" ] && \
        show "$(awk -v i="$i" -v v="$v" 'BEGIN{print (i/1e6)*(v/1e6)}')" && exit 0
done

# 2) hwmon INA-style sensor: power1_input (µW), else curr1_input(mA)*in1_input(mV).
for h in /sys/class/hwmon/*; do
    [ -d "$h" ] || continue
    uw=$(cat "$h/power1_input" 2>/dev/null)
    [ -n "$uw" ] && show "$(awk -v x="$uw" 'BEGIN{print x/1e6}')" && exit 0
    a=$(cat "$h/curr1_input" 2>/dev/null); b=$(cat "$h/in1_input" 2>/dev/null)
    [ -n "$a" ] && [ -n "$b" ] && \
        show "$(awk -v a="$a" -v b="$b" 'BEGIN{print (a/1e3)*(b/1e3)}')" && exit 0
done

exit 0
