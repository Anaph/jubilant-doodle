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

# --- Nerd Font -------------------------------------------------------------
# NvChad/devicons (and many TUIs) need a Nerd Font, or their glyphs show as
# boxes. Install FiraCode Nerd Font (same look as Fira Code, plus the glyphs).
FONT_DIR="$TARGET_HOME/.local/share/fonts"
if ! fc-list 2>/dev/null | grep -qiF "FiraCode Nerd Font"; then
    log_info "Installing FiraCode Nerd Font (editor/terminal glyphs)…"
    run_as_user mkdir -p "$FONT_DIR/FiraCodeNerdFont"
    if run_as_user bash -c "curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -o '$FONT_DIR/firacode-nf.zip' && unzip -oq '$FONT_DIR/firacode-nf.zip' -d '$FONT_DIR/FiraCodeNerdFont' && rm -f '$FONT_DIR/firacode-nf.zip'"; then
        run_as_user fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
        log_ok "FiraCode Nerd Font installed"
    else
        log_warn "Couldn't download the Nerd Font (offline?); some editor glyphs may show as boxes"
    fi
fi
# Switch Alacritty to the Nerd Font when it's available.
if fc-list 2>/dev/null | grep -qiF "FiraCode Nerd Font"; then
    run_as_user sed -i 's/family = "Fira Code"/family = "FiraCode Nerd Font Mono"/g' "$ALACRITTY_TOML"
fi

log_ok "Alacritty themed with '$THEME'"
