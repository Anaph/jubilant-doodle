#!/bin/sh
# uConsole CPU governor (run at boot by uconsole-cpufreq.service).
# schedutil scales frequency with load — the efficient default. For maximum
# battery set GOV=powersave; to cap peak power, also write a scaling_max_freq
# below cpuinfo_max_freq in the loop below.

GOV=schedutil

for d in /sys/devices/system/cpu/cpu*/cpufreq; do
    [ -w "$d/scaling_governor" ] && echo "$GOV" >"$d/scaling_governor"
    # Example power cap (uncomment to limit peak frequency to ~85%):
    # max=$(cat "$d/cpuinfo_max_freq" 2>/dev/null) && \
    #     echo $((max * 85 / 100)) >"$d/scaling_max_freq"
done

exit 0
