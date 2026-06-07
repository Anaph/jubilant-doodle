# shellcheck shell=bash
#
# 70_extras.sh — optional curated extra packages (--extras) and a Neovim + NvChad
# setup (--neovim, implied by --extras). Sourced by install.sh; no-op otherwise.

[ "${EXTRAS:-0}" = 1 ] || [ "${NEOVIM:-0}" = 1 ] || { log_info "Extras not requested (use --extras)"; return 0; }

log_step "Extra packages and tools"

# --- Curated extra package bundles -----------------------------------------
if [ "${EXTRAS:-0}" = 1 ]; then
    MAN="$REPO_DIR/packages-extra.txt"
    [ -f "$MAN" ] || die "missing $MAN"
    EXTRA_PKGS=()
    while IFS= read -r line; do
        line="${line%%#*}"; line="${line//[[:space:]]/}"
        [ -n "$line" ] && EXTRA_PKGS+=("$line")
    done <"$MAN"
    log_info "Installing ${#EXTRA_PKGS[@]} extra packages…"
    # Install the whole set at once; if any single package is unavailable, fall
    # back to one-by-one so the rest still get installed.
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${EXTRA_PKGS[@]}"; then
        log_warn "Bulk install failed; retrying package-by-package (skipping missing ones)"
        for p in "${EXTRA_PKGS[@]}"; do
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" \
                || log_warn "skipped (unavailable?): $p"
        done
    fi
    log_ok "Extra packages done"
fi

# --- Neovim + NvChad -------------------------------------------------------
if [ "${NEOVIM:-0}" = 1 ]; then
    log_info "Setting up Neovim + NvChad"

    # Editor + C/C++/CMake toolchain (clangd LSP, clang-format, treesitter build).
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        neovim clang clangd clang-format clang-tidy cmake ripgrep fd-find git \
        || log_warn "some Neovim toolchain packages may be missing"

    NVIM_DIR="$TARGET_HOME/.config/nvim"
    STARTER="https://github.com/NvChad/starter"

    if [ -d "$NVIM_DIR/.git" ]; then
        log_info "Existing Neovim config at $NVIM_DIR — keeping it, updating dev.lua only"
    else
        if [ -e "$NVIM_DIR" ] && [ -n "$(ls -A "$NVIM_DIR" 2>/dev/null)" ]; then
            bak="$NVIM_DIR.bak.$(date +%Y%m%d-%H%M%S)"
            run_as_user mv "$NVIM_DIR" "$bak"
            log_info "Backed up existing $NVIM_DIR -> $bak"
        fi
        log_info "Cloning NvChad starter -> $NVIM_DIR"
        run_as_user git clone --depth 1 "$STARTER" "$NVIM_DIR"
    fi

    # Deploy our plugin spec and point the NvChad core at the configured fork.
    install_config "$REPO_DIR/config/nvim/dev.lua" "$NVIM_DIR/lua/plugins/dev.lua"
    esc_repo="$(printf '%s' "$NVCHAD_REPO" | sed 's/[&/|]/\\&/g')"
    run_as_user sed -i "s|__NVCHAD_REPO__|$esc_repo|g" "$NVIM_DIR/lua/plugins/dev.lua"

    # Optional CMake language server (best-effort; pipx comes with --extras).
    if command -v pipx >/dev/null 2>&1; then
        if run_as_user pipx install cmake-language-server >/dev/null 2>&1; then
            log_info "Installed cmake-language-server (pipx)"
        else
            log_info "cmake-language-server not installed (optional)"
        fi
    fi

    log_ok "Neovim + NvChad ready (core: $NVCHAD_REPO)"
    log_info "Launch 'nvim' once to install plugins, or headless: nvim --headless \"+Lazy! sync\" +qa"
fi
