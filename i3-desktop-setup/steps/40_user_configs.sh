# shellcheck shell=bash
#
# 40_user_configs.sh — deploy all user dotfiles and apply the i3 theme palette
# (kept in sync with the chosen Alacritty theme). Sourced by install.sh.

log_step "Deploying desktop configuration"

CFG="$REPO_DIR/config"

# --- Core dotfiles ---------------------------------------------------------
install_config "$CFG/i3/config"            "$TARGET_HOME/.config/i3/config"
install_config "$CFG/i3/scripts/set-wallpaper.sh" \
                                           "$TARGET_HOME/.config/i3/scripts/set-wallpaper.sh" 0755
install_config "$CFG/i3/scripts/polkit-agent.sh" \
                                           "$TARGET_HOME/.config/i3/scripts/polkit-agent.sh" 0755
install_config "$CFG/i3status/config"      "$TARGET_HOME/.config/i3status/config"
install_config "$CFG/picom/picom.conf"     "$TARGET_HOME/.config/picom/picom.conf"
install_config "$CFG/dunst/dunstrc"        "$TARGET_HOME/.config/dunst/dunstrc"
install_config "$CFG/rofi/config.rasi"     "$TARGET_HOME/.config/rofi/config.rasi"
install_config "$CFG/x11/xinitrc"          "$TARGET_HOME/.xinitrc"          0755
install_config "$CFG/x11/xsessionrc"       "$TARGET_HOME/.xsessionrc"

# --- i3 colour palette (themes the WM to match the terminal) ---------------
# Only a curated set ships an i3 palette; anything else falls back to tokyo_night.
case "$THEME" in
    tokyo_night|catppuccin_mocha|gruvbox_dark|nord) I3_PALETTE="$THEME" ;;
    *) I3_PALETTE="tokyo_night"
       log_warn "No i3 palette for '$THEME'; theming i3 with tokyo_night." ;;
esac
# Inline the palette in place of the "# __PALETTE__" marker, so window colours do
# NOT depend on i3's `include` directive (which may be unavailable/older i3).
PALETTE_FILE="$CFG/i3/colors/${I3_PALETTE}.conf"
I3DEST="$TARGET_HOME/.config/i3/config"
i3tmp="$(mktemp)"
awk -v pf="$PALETTE_FILE" '
    /# __PALETTE__/ { while ((getline l < pf) > 0) print l; close(pf); next }
    { print }
' "$I3DEST" >"$i3tmp"
cat "$i3tmp" >"$I3DEST"
rm -f "$i3tmp"
log_info "i3 palette inlined: $I3_PALETTE"

# --- Wallpaper -------------------------------------------------------------
# A solid colour (via xsetroot) always works; if ImageMagick happens to be
# installed we also render a subtle gradient PNG for feh to use.
ASSET_DIR="$TARGET_HOME/.local/share/i3-desktop-setup"
run_as_user mkdir -p "$ASSET_DIR"
case "$I3_PALETTE" in
    tokyo_night)      WP_BG="#1a1b26" ;;
    catppuccin_mocha) WP_BG="#1e1e2e" ;;
    gruvbox_dark)     WP_BG="#282828" ;;
    nord)             WP_BG="#2e3440" ;;
    *)                WP_BG="#1a1b26" ;;
esac
# Solid colour as the fallback (used by set-wallpaper.sh if feh is unavailable).
printf '%s\n' "$WP_BG" | run_as_user tee "$ASSET_DIR/wallpaper-color" >/dev/null
# Deploy the shipped futuristic wallpaper; set-wallpaper.sh shows it via feh.
install_config "$CFG/wallpaper/futuristic.png" "$ASSET_DIR/wallpaper.png" 0644
log_info "Futuristic wallpaper deployed"

# --- XDG user dirs (~/Downloads etc. for the file manager) -----------------
if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    run_as_user xdg-user-dirs-update || true
fi

log_ok "Configuration deployed"
