# shellcheck shell=bash
#
# 10_apt_packages.sh — install the desktop stack from packages.txt.
# Sourced by install.sh.

log_step "Installing packages"

MANIFEST="$REPO_DIR/packages.txt"
[ -f "$MANIFEST" ] || die "package manifest not found: $MANIFEST"

# Packages dropped when --minimal is given: the "nice-to-have" desktop glue.
# The window manager, terminal, Xorg, fonts, audio and networking always stay.
MINIMAL_SKIP=(
    picom dunst libnotify-bin
    thunar gvfs
    lxappearance arc-theme papirus-icon-theme
    maim scrot xclip
    pavucontrol brightnessctl
    jq unzip wget build-essential pkg-config
)

skip_pkg() {
    [ "$MINIMAL" = 1 ] || return 1
    local p
    for p in "${MINIMAL_SKIP[@]}"; do
        [ "$p" = "$1" ] && return 0
    done
    return 1
}

PKGS=()
while IFS= read -r line; do
    line="${line%%#*}"                 # strip comments
    line="${line//[[:space:]]/}"       # strip whitespace
    [ -n "$line" ] || continue
    if skip_pkg "$line"; then
        log_info "Skipping (minimal): $line"
        continue
    fi
    PKGS+=("$line")
done <"$MANIFEST"

[ "${#PKGS[@]}" -gt 0 ] || die "no packages parsed from $MANIFEST"

log_info "Installing ${#PKGS[@]} packages (this can take a while on the Pi)…"
# Install the whole set at once; if any single package is unavailable (e.g. a
# renamed/removed package on a newer Debian), fall back to one-by-one so one bad
# name never aborts the entire desktop install.
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"; then
    log_warn "Bulk install failed; retrying package-by-package (skipping unavailable ones)"
    failed=()
    for p in "${PKGS[@]}"; do
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" || failed+=("$p")
    done
    [ "${#failed[@]}" -gt 0 ] && log_warn "Skipped unavailable packages: ${failed[*]}"
fi
log_ok "Package installation complete"
