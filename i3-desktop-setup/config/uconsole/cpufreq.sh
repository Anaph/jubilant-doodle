#!/bin/sh
# uConsole CPU governor (run at boot by uconsole-cpufreq.service).
# powersave pins the CPU to its lowest frequency for maximum battery life. For a
# snappier device set GOV=schedutil (scales with load) or ondemand.

GOV=powersave

for d in /sys/devices/system/cpu/cpu*/cpufreq; do
    [ -w "$d/scaling_governor" ] && echo "$GOV" >"$d/scaling_governor"
    # Example power cap (uncomment to limit peak frequency to ~85%):
    # max=$(cat "$d/cpuinfo_max_freq" 2>/dev/null) && \
    #     echo $((max * 85 / 100)) >"$d/scaling_max_freq"
done

exit 0
