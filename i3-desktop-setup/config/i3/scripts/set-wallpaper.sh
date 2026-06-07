#!/usr/bin/env bash
#
# set-wallpaper.sh — set the desktop background.
# Prefers a generated PNG (via feh); otherwise paints a solid themed colour
# (via xsetroot). The colour and optional image are produced by the installer
# and live in ~/.local/share/i3-desktop-setup/.
set -euo pipefail

ASSET_DIR="$HOME/.local/share/i3-desktop-setup"
IMG="$ASSET_DIR/wallpaper.png"
COLOR_FILE="$ASSET_DIR/wallpaper-color"

if [ -f "$IMG" ] && command -v feh >/dev/null 2>&1; then
    exec feh --no-fehbg --bg-fill "$IMG"
fi

color="#1a1b26"
[ -f "$COLOR_FILE" ] && color="$(cat "$COLOR_FILE")"

if command -v xsetroot >/dev/null 2>&1; then
    exec xsetroot -solid "$color"
fi
