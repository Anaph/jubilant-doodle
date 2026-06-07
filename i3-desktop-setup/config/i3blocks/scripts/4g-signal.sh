#!/usr/bin/env bash
#
# 4g-signal.sh — show 4G signal from a Huawei HiLink dongle (e.g. E3372h-153).
# Reads the dongle's web API. Prints nothing (empty block) when the dongle is
# absent or unreachable, so the bar stays clean.
#
# MODEM_IP is substituted at install time from --modem-ip (default 128.128.66.1).

MODEM_IP="128.128.66.1"
base="http://$MODEM_IP"

fetch()  { curl -fsS --max-time 2 "$@" 2>/dev/null; }
xmlval() { sed -n "s:.*<$1>\(.*\)</$1>.*:\1:p"; }

signal="$(fetch "$base/api/device/signal")"

# Some firmwares require a session id + verification token for this endpoint.
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
