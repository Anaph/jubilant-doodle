#!/usr/bin/env bash
# volume.sh — current sink volume via WirePlumber (PipeWire).
command -v wpctl >/dev/null 2>&1 || exit 0
line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)" || exit 0
case "$line" in
    *MUTED*) printf 'vol mute\n' ;;
    *) printf 'vol %d%%\n' "$(printf '%s' "$line" | awk '{printf "%d", $2*100}')" ;;
esac
