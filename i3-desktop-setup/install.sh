#!/usr/bin/env bash
#
# install.sh — orchestrator for the i3 desktop setup.
#
# Validates the environment, parses options, then runs each steps/NN_*.sh in
# order. Can be run directly from a checkout (it does not need bootstrap.sh):
#
#   ./install.sh [--boot=lightdm|startx] [--theme=NAME] [--no-claude]
#                [--minimal] [--yes]
#
# Run as your NORMAL user. The script asks for sudo only where it needs it.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR

# --- Defaults / options ----------------------------------------------------
BOOT_METHOD="lightdm"     # lightdm | startx
THEME="tokyo_night"       # any alacritty-theme name; curated palettes also theme i3
INSTALL_CLAUDE=1
MINIMAL=0
ASSUME_YES=0
UCONSOLE=0                # ClockworkPi uConsole (CM5) hardware tweaks
UCONSOLE_SIGNAL=0         # add a 4G-signal bar widget (Huawei HiLink dongle)
MODEM_IP="192.168.98.1"   # HiLink dongle web/API address
ROTATE="right"            # uConsole panel rotation: right|left|normal|inverted|skip
EXTRAS=0                  # install the curated extra package bundles
NEOVIM=0                  # set up Neovim + NvChad (implied by --extras)
NO_NVIM=0                 # with --extras, opt out of the Neovim setup
NVCHAD_REPO="https://github.com/Anaph/NvChad"  # NvChad core fork (branch v2.5)

usage() {
    cat <<'EOF'
i3 desktop setup for Raspberry Pi CM5 (Debian Trixie)

Usage: ./install.sh [options]

Options:
  --boot=lightdm|startx   How the desktop starts (default: lightdm).
                          lightdm = graphical login screen.
                          startx  = console autologin on tty1 -> startx -> i3.
  --theme=NAME            Alacritty theme name (default: tokyo_night). The
                          curated names tokyo_night, catppuccin_mocha,
                          gruvbox_dark and nord also theme i3 itself.
  --no-claude             Skip installing Claude Code.
  --minimal               Skip the extra "nice-to-have" desktop glue.
  --uconsole              Apply ClockworkPi uConsole (CM5) tweaks: screen
                          rotation, battery in the bar, Bluetooth, USB HiLink
                          modem support, power saving (tlp/zram), larger 720p
                          fonts.
  --uconsole-signal       Like --uconsole, plus a 4G-signal widget in the bar
                          (reads a Huawei HiLink dongle's HTTP API).
  --modem-ip=IP           HiLink dongle address for the signal widget
                          (default: 192.168.98.1).
  --rotate=DIR            uConsole panel rotation: right|left|normal|inverted|skip
                          (default: right).
  --extras                Install curated extra packages (cyberdeck, CLI/dev,
                          network) and set up Neovim + NvChad.
  --neovim                Set up Neovim + NvChad only (implied by --extras).
  --no-nvim               With --extras, skip the Neovim/NvChad setup.
  --nvchad-repo=URL       NvChad core repo to use (default: the Anaph/NvChad
                          fork, branch v2.5).
  --yes                   Assume "yes"; do not prompt.
  -h, --help              Show this help and exit.

Run as your normal (sudo-capable) user, NOT as root.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --boot=*)  BOOT_METHOD="${arg#*=}" ;;
        --theme=*) THEME="${arg#*=}" ;;
        --no-claude) INSTALL_CLAUDE=0 ;;
        --minimal)   MINIMAL=1 ;;
        --uconsole)  UCONSOLE=1 ;;
        --uconsole-signal) UCONSOLE=1; UCONSOLE_SIGNAL=1 ;;
        --modem-ip=*) MODEM_IP="${arg#*=}" ;;
        --rotate=*)  ROTATE="${arg#*=}" ;;
        --extras)    EXTRAS=1; NEOVIM=1 ;;
        --neovim)    NEOVIM=1 ;;
        --no-nvim)   NO_NVIM=1 ;;
        --nvchad-repo=*) NVCHAD_REPO="${arg#*=}" ;;
        --yes|-y)    ASSUME_YES=1 ;;
        -h|--help)   usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done
[ "$NO_NVIM" = 1 ] && NEOVIM=0

case "$BOOT_METHOD" in
    lightdm|startx) ;;
    *) echo "Invalid --boot value: $BOOT_METHOD (expected lightdm or startx)" >&2; exit 2 ;;
esac

# --- Refuse root, resolve the target user/home -----------------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "Do NOT run install.sh as root or with sudo." >&2
    echo "Log in as your normal user and run it again; it will sudo when needed." >&2
    exit 1
fi
TARGET_USER="$(id -un)"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || TARGET_HOME="$HOME"
export TARGET_USER TARGET_HOME
export BOOT_METHOD THEME INSTALL_CLAUDE MINIMAL ASSUME_YES
export UCONSOLE UCONSOLE_SIGNAL MODEM_IP ROTATE
export EXTRAS NEOVIM NVCHAD_REPO

# --- Load helpers ----------------------------------------------------------
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

# --- Run steps in order ----------------------------------------------------
CURRENT_STEP="(startup)"
_on_exit() {
    local rc=$?
    [ "$rc" -ne 0 ] && log_error "Failed during step: $CURRENT_STEP (exit $rc)"
    return 0
}
trap _on_exit EXIT

STEPS=(
    00_preflight
    10_apt_packages
    20_claude_code
    30_alacritty_themes
    40_user_configs
    50_boot_method
    60_uconsole
    70_extras
    99_summary
)

log_step "i3 desktop setup starting"
log_info "User: $TARGET_USER   Home: $TARGET_HOME"
log_info "Boot: $BOOT_METHOD   Theme: $THEME   Claude: $([ "$INSTALL_CLAUDE" = 1 ] && echo yes || echo no)   Minimal: $([ "$MINIMAL" = 1 ] && echo yes || echo no)"

for step in "${STEPS[@]}"; do
    CURRENT_STEP="$step"
    # shellcheck source=/dev/null
    source "$REPO_DIR/steps/$step.sh"
done

trap - EXIT
