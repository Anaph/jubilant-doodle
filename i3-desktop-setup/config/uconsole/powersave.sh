#!/bin/sh
# uconsole-powersave {sleep|wake} — the privileged parts of the deep "sleep":
# CPU governor, the Wi-Fi radio, NetworkManager, and USB-suspending the built-in
# keyboard/trackball (their HID polling is the main idle wakeup source). Run as
# root via sudo from uconsole-sleep. Bluetooth is left alone (off by default).
#
# Waking is via the power button (a separate input device), so suspending the
# keyboard here is safe — it resumes on the first keypress when you unlock.

gov() {
    for d in /sys/devices/system/cpu/cpu*/cpufreq; do
        [ -w "$d/scaling_governor" ] && echo "$1" >"$d/scaling_governor"
    done
}

# USB device dirs of HID keyboards (interface class 03, protocol 01) and mice
# (protocol 02) — i.e. the built-in keyboard and trackball.
hid_input_devs() {
    for proto in /sys/bus/usb/devices/*:*/bInterfaceProtocol; do
        [ -r "$proto" ] || continue
        case "$(cat "$proto" 2>/dev/null)" in 01|02) : ;; *) continue ;; esac
        idir=${proto%/bInterfaceProtocol}
        [ "$(cat "$idir/bInterfaceClass" 2>/dev/null)" = "03" ] || continue
        printf '%s\n' "${idir%:*}"
    done | sort -u
}

# set_hid <control: auto|on> <delay_ms>
set_hid() {
    hid_input_devs | while IFS= read -r d; do
        [ -w "$d/power/control" ] && echo "$1" >"$d/power/control" 2>/dev/null
        [ -n "$2" ] && [ -w "$d/power/autosuspend_delay_ms" ] && \
            echo "$2" >"$d/power/autosuspend_delay_ms" 2>/dev/null
    done
}

case "$1" in
    sleep)
        gov powersave
        rfkill block wifi 2>/dev/null
        nmcli networking off 2>/dev/null
        set_hid auto 0          # let the keyboard/trackball suspend immediately
        ;;
    wake)
        gov powersave
        rfkill unblock wifi 2>/dev/null
        nmcli networking on 2>/dev/null
        set_hid auto 2000       # responsive now; re-suspends after 2 s idle
        ;;
    *)
        echo "usage: uconsole-powersave {sleep|wake}" >&2
        ;;
esac

exit 0
