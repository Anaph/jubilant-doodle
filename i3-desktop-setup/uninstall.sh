#!/usr/bin/env bash
#
# uninstall.sh — reverse what install.sh did.
#
#   ./uninstall.sh           restore configs, remove autologin + cloned assets
#   ./uninstall.sh --purge   also apt-purge the installed packages + lightdm
#   ./uninstall.sh --yes     do not prompt for confirmation
#
# Run as the same normal user the desktop was installed for (NOT root).
#
# The literal $HOME/$PATH strings in the remove_line calls below are intentional
# (matched verbatim against the user's profile files), so single quotes are
# correct and SC2016 is disabled file-wide.
# shellcheck disable=SC2016
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR

PURGE=0
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    echo "Do NOT run uninstall.sh as root. Run as your normal user." >&2
    exit 1
fi
TARGET_USER="$(id -un)"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || TARGET_HOME="$HOME"
export TARGET_USER TARGET_HOME

# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

confirm() {
    [ "$ASSUME_YES" = 1 ] && return 0
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Restore the newest backup of a file if one exists, otherwise remove the file.
# Backups are named <file>.bak.YYYYmmdd-HHMMSS, so the lexically-last glob match
# is the most recent one.
restore_or_remove() {
    local f="$1" newest="" b
    for b in "$f".bak.*; do
        [ -e "$b" ] && newest="$b"
    done
    if [ -n "$newest" ]; then
        cp -a "$newest" "$f"
        log_info "Restored $f from $(basename "$newest")"
    elif [ -e "$f" ]; then
        rm -f "$f"
        log_info "Removed $f"
    fi
}

# Remove an exact line from a file (if present).
remove_line() {
    local file="$1" line="$2"
    [ -f "$file" ] || return 0
    grep -vxF -- "$line" "$file" >"$file.tmp" && mv "$file.tmp" "$file"
}

log_step "Uninstalling i3 desktop setup"

# --- Restore / remove deployed dotfiles ------------------------------------
for f in \
    "$TARGET_HOME/.config/i3/config" \
    "$TARGET_HOME/.config/i3/colors.conf" \
    "$TARGET_HOME/.config/i3/scripts/set-wallpaper.sh" \
    "$TARGET_HOME/.config/i3/scripts/polkit-agent.sh" \
    "$TARGET_HOME/.config/i3/scripts/uconsole.sh" \
    "$TARGET_HOME/.config/i3status/config" \
    "$TARGET_HOME/.config/i3blocks/config" \
    "$TARGET_HOME/.config/i3blocks/scripts/4g-signal.sh" \
    "$TARGET_HOME/.config/i3blocks/scripts/cpu-graph.sh" \
    "$TARGET_HOME/.config/i3blocks/scripts/battery.sh" \
    "$TARGET_HOME/.config/picom/picom.conf" \
    "$TARGET_HOME/.config/dunst/dunstrc" \
    "$TARGET_HOME/.config/rofi/config.rasi" \
    "$TARGET_HOME/.config/alacritty/alacritty.toml" \
    "$TARGET_HOME/.config/nvim/lua/plugins/dev.lua" \
    "$TARGET_HOME/.xinitrc" \
    "$TARGET_HOME/.xsessionrc"
do
    restore_or_remove "$f"
done

# --- Remove appended profile lines -----------------------------------------
remove_line "$TARGET_HOME/.profile" 'export PATH="$HOME/.local/bin:$PATH"'
remove_line "$TARGET_HOME/.bashrc"  'export PATH="$HOME/.local/bin:$PATH"'
remove_line "$TARGET_HOME/.bash_profile" '[ -f "$HOME/.profile" ] && . "$HOME/.profile"'
remove_line "$TARGET_HOME/.bash_profile" 'if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'

# --- Remove cloned / generated assets --------------------------------------
if [ -d "$TARGET_HOME/.config/alacritty/themes" ] && \
   confirm "Remove cloned Alacritty theme collection (~/.config/alacritty/themes)?"; then
    rm -rf "$TARGET_HOME/.config/alacritty/themes"
    log_info "Removed Alacritty theme collection"
fi
rm -rf "$TARGET_HOME/.local/share/i3-desktop-setup"
log_info "Removed generated assets (wallpaper, etc.)"

# --- Undo boot configuration -----------------------------------------------
AUTOLOGIN_DROPIN="/etc/systemd/system/getty@tty1.service.d/override.conf"
if [ -f "$AUTOLOGIN_DROPIN" ]; then
    need_sudo
    sudo rm -f "$AUTOLOGIN_DROPIN"
    sudo rmdir --ignore-fail-on-non-empty "$(dirname "$AUTOLOGIN_DROPIN")" 2>/dev/null || true
    sudo systemctl daemon-reload
    log_info "Removed tty1 autologin drop-in"
fi

# --- Undo LightDM greeter theming ------------------------------------------
if [ -f /etc/lightdm/lightdm.conf.d/20-uconsole-greeter.conf ] \
   || [ -f /etc/lightdm/lightdm-gtk-greeter.conf.i3ds.bak ]; then
    need_sudo
    sudo rm -f /etc/lightdm/lightdm.conf.d/20-uconsole-greeter.conf \
        /usr/share/backgrounds/uconsole-futuristic.png
    if [ -f /etc/lightdm/lightdm-gtk-greeter.conf.i3ds.bak ]; then
        sudo mv /etc/lightdm/lightdm-gtk-greeter.conf.i3ds.bak \
            /etc/lightdm/lightdm-gtk-greeter.conf
    fi
    log_info "Reverted LightDM greeter theming"
fi

# --- Undo uConsole power-saving services + Bluetooth state -----------------
if [ -f /etc/systemd/system/uconsole-cpufreq.service ] || \
   [ -f /etc/systemd/system/uconsole-rfkill-bt.service ]; then
    need_sudo
    sudo systemctl disable --now uconsole-cpufreq.service uconsole-rfkill-bt.service 2>/dev/null || true
    sudo rfkill unblock bluetooth 2>/dev/null || true
    sudo systemctl enable bluetooth 2>/dev/null || true   # restore (we had disabled it)
fi

# aiov2_ctl (HackerGadgets AIO v2 tool), if we installed it.
if [ -f /etc/systemd/system/aiov2-rails-boot.service ] || [ -f /usr/local/bin/aiov2_ctl ]; then
    need_sudo
    sudo systemctl disable --now aiov2-rails-boot.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/aiov2-rails-boot.service /usr/local/bin/aiov2_ctl
    log_info "Removed aiov2_ctl"
fi
rm -rf "$TARGET_HOME/.local/share/aiov2_ctl"

# --- Undo uConsole system files --------------------------------------------
# Capture whether the extra power tweaks were installed (files are removed below,
# so the flag must be read first) to know whether to restore timers/configs.
POWER_TWEAKS=0
[ -f /etc/sysctl.d/60-uconsole-powersave.conf ] && POWER_TWEAKS=1
for sysf in \
    /etc/udev/rules.d/99-huawei-hilink.rules \
    /etc/tlp.d/01-uconsole.conf \
    /etc/NetworkManager/conf.d/01-uconsole-powersave.conf \
    /etc/sysctl.d/60-uconsole-powersave.conf \
    /etc/systemd/journald.conf.d/01-uconsole-powersave.conf \
    /etc/lightdm/lightdm.conf.d/10-uconsole-rotate.conf \
    /etc/systemd/logind.conf.d/10-uconsole-powerkey.conf \
    /usr/local/bin/uconsole-rotate.sh \
    /usr/local/bin/uconsole-cpufreq \
    /usr/local/bin/uconsole-bl-toggle \
    /usr/local/bin/uconsole-sleep \
    /usr/local/bin/uconsole-powersave \
    /usr/local/bin/uconsole-powerd \
    /usr/local/bin/uconsole-idle-dim \
    /usr/local/bin/uconsole-usb-toggle \
    /etc/sudoers.d/010-uconsole-powersave \
    /etc/systemd/system/uconsole-cpufreq.service \
    /etc/systemd/system/uconsole-rfkill-bt.service; do
    if [ -f "$sysf" ]; then
        need_sudo
        sudo rm -f "$sysf"
        log_info "Removed $sysf"
    fi
done
sudo systemctl daemon-reload 2>/dev/null || true

# Restore the maintenance timers/services we disabled and reload the configs we
# changed for power saving (only if those tweaks were installed).
if [ "$POWER_TWEAKS" = 1 ]; then
    need_sudo
    sudo systemctl unmask packagekit.service 2>/dev/null || true
    for unit in apt-daily.timer apt-daily-upgrade.timer man-db.timer e2scrub_all.timer fwupd-refresh.timer; do
        sudo systemctl enable --now "$unit" 2>/dev/null || true
    done
    sudo nmcli general reload conf 2>/dev/null || true
    sudo sysctl -q --system 2>/dev/null || true
    sudo systemctl restart systemd-journald 2>/dev/null || true
    log_info "Restored maintenance timers; reloaded NM/sysctl/journald to defaults"
fi

# Remove the config.txt blocks we added (underclock + LED power saving).
for cfg in /boot/firmware/config.txt /boot/config.txt; do
    if [ -f "$cfg" ] && grep -qE 'i3ds-underclock|i3ds-power' "$cfg"; then
        need_sudo
        sudo sed -i '/# >>> i3ds-underclock >>>/,/# <<< i3ds-underclock <<</d' "$cfg"
        sudo sed -i '/# >>> i3ds-power >>>/,/# <<< i3ds-power <<</d' "$cfg"
        log_info "Removed i3ds config.txt blocks from $cfg"
    fi
done

# Strip the USB HID poll-rate params we appended to cmdline.txt (if present).
for cmd in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
    if [ -f "$cmd" ] && grep -qE 'usbhid\.(mousepoll|kbpoll|jspoll)=[0-9]+' "$cmd"; then
        need_sudo
        sudo sed -i -E 's/[[:space:]]+usbhid\.(mousepoll|kbpoll|jspoll)=[0-9]+//g' "$cmd"
        log_info "Removed USB HID poll params from $cmd (reboot to apply)"
    fi
done

# --- Optional: purge packages ----------------------------------------------
if [ "$PURGE" = 1 ]; then
    if confirm "apt-purge ALL packages from packages.txt (this removes Xorg, i3, etc.)?"; then
        need_sudo
        PKGS=()
        for manifest in "$REPO_DIR/packages.txt" "$REPO_DIR/packages-extra.txt"; do
            [ -f "$manifest" ] || continue
            while IFS= read -r line; do
                line="${line%%#*}"; line="${line//[[:space:]]/}"
                [ -n "$line" ] && PKGS+=("$line")
            done <"$manifest"
        done
        sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y "${PKGS[@]}" \
            lightdm lightdm-gtk-greeter \
            blueman bluez usb-modeswitch usb-modeswitch-data tlp powertop zram-tools \
            clang clangd clang-format clang-tidy cmake || true
        sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
        sudo systemctl set-default multi-user.target || true
        log_info "Packages purged"
    fi
fi

log_ok "Uninstall complete. Note: Claude Code (~/.local/bin/claude) was left in place."
