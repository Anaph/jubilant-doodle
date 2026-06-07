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
install_config "$CFG/i3/colors/${I3_PALETTE}.conf" "$TARGET_HOME/.config/i3/colors.conf"
log_info "i3 palette: $I3_PALETTE"

# --- Wallpaper -------------------------------------------------------------
# A solid colour (via xsetroot) always works; if ImageMagick happens to be
# installed we also render a subtle gradient PNG for feh to use.
ASSET_DIR="$TARGET_HOME/.local/share/i3-desktop-setup"
run_as_user mkdir -p "$ASSET_DIR"
case "$I3_PALETTE" in
    tokyo_night)      WP_BG="#1a1b26"; WP_GRAD="#24283b" ;;
    catppuccin_mocha) WP_BG="#1e1e2e"; WP_GRAD="#313244" ;;
    gruvbox_dark)     WP_BG="#282828"; WP_GRAD="#3c3836" ;;
    nord)             WP_BG="#2e3440"; WP_GRAD="#3b4252" ;;
    *)                WP_BG="#1a1b26"; WP_GRAD="#24283b" ;;
esac
printf '%s\n' "$WP_BG" | run_as_user tee "$ASSET_DIR/wallpaper-color" >/dev/null
if command -v convert >/dev/null 2>&1; then
    if run_as_user convert -size 1920x1080 "gradient:${WP_GRAD}-${WP_BG}" \
            "$ASSET_DIR/wallpaper.png" 2>/dev/null; then
        log_info "Generated gradient wallpaper"
    else
        log_warn "Wallpaper generation failed; falling back to solid colour"
    fi
else
    log_info "ImageMagick not present; using solid '$WP_BG' background"
fi

# --- XDG user dirs (~/Downloads etc. for the file manager) -----------------
if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    run_as_user xdg-user-dirs-update || true
fi

log_ok "Configuration deployed"
