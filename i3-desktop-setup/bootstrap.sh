#!/usr/bin/env bash
#
# bootstrap.sh — one-command entrypoint for the i3 desktop setup.
#
# This is the ONLY file fetched over the network (curl | bash). It makes sure
# git is available, clones (or updates) the repository into a stable location,
# and hands off to install.sh. Everything else — the installer logic and all
# config files — travels with the clone, so the configs always match the code.
#
# Usage (run as your NORMAL user, do NOT prefix with sudo):
#
#   curl -fsSL https://raw.githubusercontent.com/Anaph/jubilant-doodle/claude/focused-mayer-hwNfz/i3-desktop-setup/bootstrap.sh | bash
#
# To pass options through the pipe, use the `bash -s --` form, e.g.:
#
#   curl -fsSL .../bootstrap.sh | bash -s -- --boot=startx --theme=nord
#
set -euo pipefail

REPO_SLUG="Anaph/jubilant-doodle"
REPO_GIT_URL="https://github.com/${REPO_SLUG}.git"
BRANCH="claude/focused-mayer-hwNfz"
# Fallback (no-git / air-gapped): a tarball is available at
#   https://codeload.github.com/${REPO_SLUG}/tar.gz/refs/heads/${BRANCH}
# which can be piped through `tar xz`. We prefer git for clean idempotent updates.

CHECKOUT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/jubilant-doodle"

_on_exit() {
    local rc=$?
    [ "$rc" -ne 0 ] && printf '\n[err ] bootstrap failed (exit %s)\n' "$rc" >&2
    return 0
}
trap _on_exit EXIT

say() { printf '==> %s\n' "$*"; }

# --- Refuse to run as root ------------------------------------------------
# Configs must land in a real user's $HOME, and (for the startx boot mode) the
# autologin must target that user — not root. The installer elevates with sudo
# only where needed, so it must be started as the unprivileged user.
if [ "$(id -u)" -eq 0 ]; then
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        echo "Do NOT run this with sudo. Re-run as your normal user:" >&2
        echo "  curl -fsSL .../bootstrap.sh | bash" >&2
    else
        echo "Do NOT run this as root. Log in as a normal (sudo-capable) user and re-run." >&2
    fi
    exit 1
fi

# --- Ensure prerequisites for cloning -------------------------------------
need_pkgs=()
command -v git  >/dev/null 2>&1 || need_pkgs+=(git)
command -v curl >/dev/null 2>&1 || need_pkgs+=(curl)
# ca-certificates has no binary to probe; add it whenever we are installing git
# or curl so HTTPS works on a bare minimal image.
[ ${#need_pkgs[@]} -gt 0 ] && need_pkgs+=(ca-certificates)

if [ ${#need_pkgs[@]} -gt 0 ]; then
    say "Installing bootstrap prerequisites: ${need_pkgs[*]}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${need_pkgs[@]}"
fi

# --- Clone or update the repository ---------------------------------------
if [ -d "$CHECKOUT_DIR/.git" ]; then
    say "Updating existing checkout at $CHECKOUT_DIR"
    git -C "$CHECKOUT_DIR" fetch --quiet --depth 1 origin "$BRANCH"
    git -C "$CHECKOUT_DIR" checkout --quiet "$BRANCH"
    git -C "$CHECKOUT_DIR" reset --quiet --hard "origin/$BRANCH"
else
    say "Cloning $REPO_GIT_URL ($BRANCH) into $CHECKOUT_DIR"
    mkdir -p "$(dirname "$CHECKOUT_DIR")"
    git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_GIT_URL" "$CHECKOUT_DIR"
fi

INSTALLER="$CHECKOUT_DIR/i3-desktop-setup/install.sh"
[ -f "$INSTALLER" ] || { echo "Installer not found at $INSTALLER" >&2; exit 1; }

trap - EXIT
say "Starting installer"
exec bash "$INSTALLER" "$@"
