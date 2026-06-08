#!/usr/bin/env bash
# cpu-graph.sh — a compact CPU-usage sparkline for i3blocks.
# Keeps a short history of usage levels between runs and renders them as block
# characters (▁▂▃▄▅▆▇█), which render with the standard fonts (no Nerd Font).

STATE="${XDG_RUNTIME_DIR:-/tmp}/i3blocks-cpu-${UID:-0}"
chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
N=12

# Aggregate CPU counters from /proc/stat.
read -r _ u ni s idle iow irq sirq _ < <(grep '^cpu ' /proc/stat)
total=$((u + ni + s + idle + iow + irq + sirq))

prev_idle=0 prev_total=0 rest=""
[ -r "$STATE" ] && read -r prev_idle prev_total rest <"$STATE"

dt=$((total - prev_total))
di=$((idle - prev_idle))
usage=0
[ "$dt" -gt 0 ] && usage=$(( (100 * (dt - di)) / dt ))
[ "$usage" -lt 0 ] && usage=0
[ "$usage" -gt 100 ] && usage=100

idx=$(( usage * 7 / 100 ))

# shellcheck disable=SC2206
hist=($rest)
hist+=("$idx")
# Keep the last N samples (front-trim; avoids the empty result that
# "${hist[@]: -N}" gives when the array is shorter than N).
while [ "${#hist[@]}" -gt "$N" ]; do hist=("${hist[@]:1}"); done

printf '%s %s %s\n' "$idle" "$total" "${hist[*]}" >"$STATE"

graph=""
for i in "${hist[@]}"; do graph+="${chars[i]}"; done
printf '%s\n' "$graph"
