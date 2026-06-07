# shellcheck shell=bash
#
# 00_preflight.sh — environment sanity checks before we touch the system.
# Sourced by install.sh; relies on helpers from lib/common.sh.

log_step "Preflight checks"

# --- OS / distribution -----------------------------------------------------
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    log_info "Detected OS: ${PRETTY_NAME:-unknown}"
    if [ "${ID:-}" != "debian" ]; then
        log_warn "This was designed for Debian; '${ID:-?}' may differ (continuing)."
    fi
    if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
        log_warn "Expected Debian 'trixie'; found '${VERSION_CODENAME:-?}' (continuing)."
    fi
else
    log_warn "/etc/os-release not found; cannot verify distribution (continuing)."
fi

# --- Architecture ----------------------------------------------------------
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
log_info "Architecture: $ARCH"
case "$ARCH" in
    arm64|aarch64) : ;;
    *) log_warn "Target hardware is Raspberry Pi CM5 (arm64); found '$ARCH' (continuing)." ;;
esac

# --- Connectivity ----------------------------------------------------------
# We need to reach the Debian mirror (apt) and, unless skipped, claude.ai.
check_host() {
    local host="$1"
    getent hosts "$host" >/dev/null 2>&1
}
if ! check_host deb.debian.org; then
    die "Cannot resolve deb.debian.org — network/DNS appears to be down. Connect to the internet and retry."
fi
if [ "$INSTALL_CLAUDE" = 1 ] && ! check_host claude.ai; then
    log_warn "Cannot resolve claude.ai; Claude Code install may fail. Use --no-claude to skip."
fi
log_ok "Network looks reachable"

# --- Privileges + package index --------------------------------------------
need_sudo
log_info "Refreshing apt package index"
sudo DEBIAN_FRONTEND=noninteractive apt-get update
log_ok "Preflight complete"
