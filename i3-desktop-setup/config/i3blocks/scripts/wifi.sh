#!/usr/bin/env bash
# wifi.sh — active Wi-Fi SSID (via NetworkManager).
command -v nmcli >/dev/null 2>&1 || exit 0
ssid="$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; exit}')"
if [ -n "$ssid" ]; then
    printf 'wifi %s\n' "$ssid"
else
    printf 'wifi --\n'
fi
