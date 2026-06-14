#!/bin/sh
# uconsole-powersave {sleep|wake} — the privileged parts of the deep "sleep":
# CPU governor, the Wi-Fi radio and NetworkManager. Run as root via sudo from
# uconsole-sleep (a narrow NOPASSWD rule allows only this fixed path).
# Bluetooth is left alone — it is off by default on the uConsole.

gov() {
    for d in /sys/devices/system/cpu/cpu*/cpufreq; do
        [ -w "$d/scaling_governor" ] && echo "$1" >"$d/scaling_governor"
    done
}

case "$1" in
    sleep)
        gov powersave
        rfkill block wifi 2>/dev/null
        nmcli networking off 2>/dev/null
        ;;
    wake)
        gov schedutil
        rfkill unblock wifi 2>/dev/null
        nmcli networking on 2>/dev/null
        ;;
    *)
        echo "usage: uconsole-powersave {sleep|wake}" >&2
        ;;
esac

exit 0
