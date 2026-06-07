# shellcheck shell=bash disable=SC2016
#
# 20_claude_code.sh — install Claude Code via the official native installer.
# (SC2016: the literal $HOME/$PATH in PATH_LINE is intentional.)
# Sourced by install.sh.

log_step "Installing Claude Code"

if [ "$INSTALL_CLAUDE" != 1 ]; then
    log_info "Skipping Claude Code (--no-claude)"
    return 0
fi

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

# Is a working `claude` reachable for the target user? (~/.local/bin from the
# native installer, or /usr/local/bin from the npm fallback — both on PATH here.)
claude_works() {
    run_as_user env PATH="$TARGET_HOME/.local/bin:$PATH" claude --version >/tmp/claude_ver 2>/dev/null
}

# 1) Official native installer (recommended): standalone binary, no Node.js,
#    supports arm64, lands in ~/.local/bin/claude. Run AS THE TARGET USER.
log_info "Installing Claude Code via the official installer (as $TARGET_USER)"
run_as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash' \
    || log_warn "Native installer reported an error; will verify and try a fallback"

# Ensure ~/.local/bin is on PATH (idempotent; the installer usually does this).
append_once "$TARGET_HOME/.profile" "$PATH_LINE"
append_once "$TARGET_HOME/.bashrc"  "$PATH_LINE"

# 2) Fallback to npm if the native install did not produce a working binary
#    (e.g. CDN/download hiccup or unsupported environment on the Pi).
if ! claude_works; then
    log_warn "Native install not working; falling back to npm (@anthropic-ai/claude-code)"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm \
        || log_warn "Could not install nodejs/npm"
    if command -v npm >/dev/null 2>&1; then
        sudo npm install -g @anthropic-ai/claude-code || log_warn "npm install of claude-code failed"
    fi
fi

# 3) Final verification (non-fatal — auth is interactive and out of scope).
if claude_works; then
    log_ok "Claude Code installed: $(cat /tmp/claude_ver)"
else
    log_warn "Claude Code is still not runnable. You can retry later with:"
    log_warn "  curl -fsSL https://claude.ai/install.sh | bash"
    log_warn "  (or: sudo npm install -g @anthropic-ai/claude-code)"
fi
rm -f /tmp/claude_ver
