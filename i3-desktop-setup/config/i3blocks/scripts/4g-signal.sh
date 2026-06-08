#!/usr/bin/env bash
# 4g-signal.sh — 4G signal from a Huawei HiLink dongle (e.g. E3372h-153) web API.
# Prints nothing when the dongle is absent/unreachable, so the block disappears.
# MODEM_IP is substituted at install time from --modem-ip (default 192.168.98.1).

MODEM_IP="192.168.98.1"
base="http://$MODEM_IP"

fetch()  { curl -fsS --max-time 2 "$@" 2>/dev/null; }
xmlval() { sed -n "s:.*<$1>\(.*\)</$1>.*:\1:p"; }

signal="$(fetch "$base/api/device/signal")"
case "$signal" in
    ""|*"<error>"*)
        tok="$(fetch "$base/api/webserver/SesTokInfo")"
        sid="$(printf '%s' "$tok" | xmlval SesInfo)"
        rtok="$(printf '%s' "$tok" | xmlval TokInfo)"
        if [ -n "$sid" ] && [ -n "$rtok" ]; then
            signal="$(fetch -H "Cookie: $sid" \
                            -H "__RequestVerificationToken: $rtok" \
                            "$base/api/device/signal")"
        fi
        ;;
esac

[ -n "$signal" ] || exit 0
rsrp="$(printf '%s' "$signal" | xmlval rsrp)"
rssi="$(printf '%s' "$signal" | xmlval rssi)"
val="${rsrp:-$rssi}"
[ -n "$val" ] || exit 0
printf '4G %s\n' "$val"
