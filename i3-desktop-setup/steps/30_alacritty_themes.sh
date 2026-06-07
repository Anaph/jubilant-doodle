# shellcheck shell=bash
#
# 30_alacritty_themes.sh — install Alacritty config + the official theme set,
# then point the config's import at the selected theme.
# Sourced by install.sh.

log_step "Configuring Alacritty + themes"

THEMES_DIR="$TARGET_HOME/.config/alacritty/themes"
ALACRITTY_TOML="$TARGET_HOME/.config/alacritty/alacritty.toml"

# Full theme collection (hundreds of palettes). Cloned idempotently.
git_clone_idempotent "https://github.com/alacritty/alacritty-theme" "$THEMES_DIR"

# Validate the requested theme exists; the .toml files live in themes/themes/.
if [ ! -f "$THEMES_DIR/themes/${THEME}.toml" ]; then
    log_warn "Alacritty theme '$THEME' not found. A few available themes:"
    if [ -d "$THEMES_DIR/themes" ]; then
        # shellcheck disable=SC2012
        ls "$THEMES_DIR/themes" | sed 's/\.toml$//' | head -n 12 | sed 's/^/    /' >&2 || true
    fi
    THEME="tokyo_night"
    log_warn "Falling back to '$THEME'."
    export THEME
fi

# Deploy the base config, then rewrite the import line to the chosen theme.
install_config "$REPO_DIR/config/alacritty/alacritty.toml" "$ALACRITTY_TOML"
run_as_user sed -i -E "s|themes/themes/[^\"]*\.toml|themes/themes/${THEME}.toml|" "$ALACRITTY_TOML"

log_ok "Alacritty themed with '$THEME'"
