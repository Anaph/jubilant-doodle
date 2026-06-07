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

# Native installer (Anthropic's recommended method). Standalone binary, no
# Node.js required, supports arm64. Lands in ~/.local/bin/claude. Run it AS THE
# TARGET USER so nothing ends up under /root.
log_info "Running https://claude.ai/install.sh as $TARGET_USER"
if ! run_as_user bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
    log_warn "Claude Code installer failed (network or auth). You can re-run later:"
    log_warn "  curl -fsSL https://claude.ai/install.sh | bash"
    return 0
fi

# Make sure ~/.local/bin is on PATH for both login and interactive shells.
# append_once is idempotent, so this is harmless if the installer already did it.
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
append_once "$TARGET_HOME/.profile" "$PATH_LINE"
append_once "$TARGET_HOME/.bashrc"  "$PATH_LINE"

# Verify (best-effort — a fresh install is unauthenticated, which is fine).
if run_as_user env PATH="$TARGET_HOME/.local/bin:$PATH" claude --version >/tmp/claude_ver 2>/dev/null; then
    log_ok "Claude Code installed: $(cat /tmp/claude_ver)"
else
    log_warn "Installed Claude Code but 'claude --version' did not run cleanly yet."
    log_warn "Open a new shell (PATH update) and run 'claude' to sign in."
fi
rm -f /tmp/claude_ver
