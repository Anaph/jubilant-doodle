# shellcheck shell=bash
#
# 60_uconsole.sh — optional ClockworkPi uConsole (CM5) tweaks. Sourced by
# install.sh; does nothing unless --uconsole (or --uconsole-signal) was given.
#
# Covers the SAFE, desktop-side bits only. Firmware-level prerequisites — the
# ClockworkPi apt repo (clockworkpi-kernel, clockworkpi-cm-firmware), the
# /boot/firmware/config.txt overlays and the CM5 EEPROM update — are documented
# in the README and intentionally left for the user to apply.

[ "${UCONSOLE:-0}" = 1 ] || { log_info "uConsole module not requested (use --uconsole)"; return 0; }

log_step "uConsole (CM5) tweaks"

CFG="$REPO_DIR/config"

# --- Packages --------------------------------------------------------------
UCON_PKGS=(bluez blueman usb-modeswitch usb-modeswitch-data tlp powertop zram-tools)
[ "$UCONSOLE_SIGNAL" = 1 ] && UCON_PKGS+=(i3blocks curl)
log_info "Installing uConsole packages: ${UCON_PKGS[*]}"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${UCON_PKGS[@]}"

# --- Services: Bluetooth + power saving ------------------------------------
sudo systemctl enable bluetooth 2>/dev/null || true

# tlp for battery life; but never autosuspend USB (would drop the LTE dongle,
# keyboard or other peripherals).
sudo install -d -m 0755 /etc/tlp.d
sudo tee /etc/tlp.d/01-uconsole.conf >/dev/null <<'EOF'
# uConsole: keep USB peripherals (LTE dongle, etc.) always powered.
USB_AUTOSUSPEND=0
EOF
sudo systemctl enable tlp 2>/dev/null || true

# zram compressed swap — valuable on a RAM-constrained handheld.
sudo tee /etc/default/zramswap >/dev/null <<'EOF'
ALGO=zstd
PERCENT=50
EOF
sudo systemctl enable zramswap 2>/dev/null || true
sudo systemctl restart zramswap 2>/dev/null || true

# Note: powertop is installed as a diagnostic tool only; we deliberately do NOT
# enable --auto-tune, which would autosuspend USB (the modem/keyboard).

# --- i3 session hook: panel rotation + Bluetooth applet --------------------
install_config "$CFG/i3/scripts/uconsole.sh" "$TARGET_HOME/.config/i3/scripts/uconsole.sh" 0755
eff_rotate="$ROTATE"; [ "$ROTATE" = "skip" ] && eff_rotate=""
run_as_user sed -i -E "s|^ROTATE=.*|ROTATE=\"$eff_rotate\"|" "$TARGET_HOME/.config/i3/scripts/uconsole.sh"
log_info "Panel rotation: ${eff_rotate:-<disabled>} (auto-detected DSI output)"

# --- LightDM greeter rotation ----------------------------------------------
# The login greeter is drawn before i3 starts, so rotate it at the
# display-manager level too — otherwise the login screen is sideways.
if [ "$BOOT_METHOD" = "lightdm" ] && [ -n "$eff_rotate" ]; then
    sudo install -D -m 0755 "$CFG/uconsole/rotate.sh" /usr/local/bin/uconsole-rotate.sh
    sudo sed -i "s/__ROTATE__/$eff_rotate/" /usr/local/bin/uconsole-rotate.sh
    sudo install -d -m 0755 /etc/lightdm/lightdm.conf.d
    sudo tee /etc/lightdm/lightdm.conf.d/10-uconsole-rotate.conf >/dev/null <<'EOF'
[Seat:*]
display-setup-script=/usr/local/bin/uconsole-rotate.sh
EOF
    log_info "LightDM greeter rotation configured ($eff_rotate)"
fi

# --- Keep ModemManager off the HiLink dongle -------------------------------
# The Huawei E3372h is a plain USB-ethernet NIC; ModemManager must not grab it.
sudo tee /etc/udev/rules.d/99-huawei-hilink.rules >/dev/null <<'EOF'
# Huawei HiLink dongle (e.g. E3372h-153): plain USB-ethernet, let NetworkManager
# handle it via DHCP. Adjust idVendor/idProduct via `lsusb` if your unit differs.
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", ENV{ID_MM_DEVICE_IGNORE}="1"
EOF
sudo udevadm control --reload-rules 2>/dev/null || true

# --- High-DPI font bumps for the 5"/720p panel -----------------------------
ALA="$TARGET_HOME/.config/alacritty/alacritty.toml"
[ -f "$ALA" ] && run_as_user sed -i -E 's|^size = .*|size = 14.0|' "$ALA"
I3CONF="$TARGET_HOME/.config/i3/config"
[ -f "$I3CONF" ] && run_as_user sed -i -E 's|^font pango:Fira Code .*|font pango:Fira Code 12|' "$I3CONF"
DUN="$TARGET_HOME/.config/dunst/dunstrc"
[ -f "$DUN" ] && run_as_user sed -i -E 's|^    font = Fira Code .*|    font = Fira Code 12|' "$DUN"
ROF="$TARGET_HOME/.config/rofi/config.rasi"
if [ -f "$ROF" ] && ! run_as_user grep -q 'font:' "$ROF"; then
    run_as_user sed -i 's|^configuration {|configuration {\n    font: "Fira Code 13";|' "$ROF"
fi
log_info "Bumped fonts for the 720p panel"

# --- Status bar: 4G signal widget (i3blocks) or battery in i3status --------
if [ "$UCONSOLE_SIGNAL" = 1 ]; then
    install_config "$CFG/i3blocks/config" "$TARGET_HOME/.config/i3blocks/config"
    for s in 4g-signal volume wifi battery; do
        install_config "$CFG/i3blocks/scripts/$s.sh" \
                       "$TARGET_HOME/.config/i3blocks/scripts/$s.sh" 0755
    done
    run_as_user sed -i -E "s|^MODEM_IP=.*|MODEM_IP=\"$MODEM_IP\"|" \
        "$TARGET_HOME/.config/i3blocks/scripts/4g-signal.sh"
    # Switch the bar generator from i3status to i3blocks.
    run_as_user sed -i 's|status_command i3status|status_command i3blocks|' "$I3CONF"
    log_ok "Bar: themed i3blocks with 4G-signal + battery (modem $MODEM_IP)"
else
    I3STATUS="$TARGET_HOME/.config/i3status/config"
    if [ -f "$I3STATUS" ] && ! run_as_user grep -q '"battery 0"' "$I3STATUS"; then
        bpath="/sys/class/power_supply/axp20x-battery/uevent"
        for p in /sys/class/power_supply/*; do
            [ -r "$p/type" ] || continue
            [ "$(cat "$p/type" 2>/dev/null)" = "Battery" ] && { bpath="$p/uevent"; break; }
        done
        run_as_user tee -a "$I3STATUS" >/dev/null <<EOF

order += "battery 0"
battery 0 {
    format = "bat %status %percentage"
    path = "$bpath"
    low_threshold = 15
    integer_battery_capacity = true
}
EOF
        log_ok "Added battery module to i3status (path: $bpath)"
    fi
fi

log_info "uConsole tweaks done. Reminder: apply the firmware-level prerequisites"
log_info "(ClockworkPi apt repo, /boot/firmware/config.txt overlays, CM5 EEPROM) — see README."
