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
UCON_PKGS=(bluez blueman usb-modeswitch usb-modeswitch-data tlp powertop zram-tools xss-lock rfkill)
log_info "Installing uConsole packages: ${UCON_PKGS[*]}"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${UCON_PKGS[@]}"

# --- Services: power saving ------------------------------------------------
# Bluetooth off by default to save power (blueman/bluez stay installed so it can
# be turned on when needed). A boot service rfkill-blocks the radio.
sudo systemctl disable bluetooth 2>/dev/null || true
sudo tee /etc/systemd/system/uconsole-rfkill-bt.service >/dev/null <<'EOF'
[Unit]
Description=uConsole: block the Bluetooth radio at boot (power saving)
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'rfkill block bluetooth || true'
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable uconsole-rfkill-bt.service 2>/dev/null || true
sudo systemctl start uconsole-rfkill-bt.service 2>/dev/null || true

# CPU governor (schedutil) pinned at boot; edit /usr/local/bin/uconsole-cpufreq
# to switch to powersave or cap the peak frequency.
sudo install -D -m 0755 "$CFG/uconsole/cpufreq.sh" /usr/local/bin/uconsole-cpufreq
sudo tee /etc/systemd/system/uconsole-cpufreq.service >/dev/null <<'EOF'
[Unit]
Description=uConsole: set an efficient CPU governor
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/uconsole-cpufreq
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable uconsole-cpufreq.service 2>/dev/null || true
sudo systemctl start uconsole-cpufreq.service 2>/dev/null || true

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
[ -f "$ALA" ] && run_as_user sed -i -E 's|^size = .*|size = 12.0|' "$ALA"
I3CONF="$TARGET_HOME/.config/i3/config"
[ -f "$I3CONF" ] && run_as_user sed -i -E 's|^font pango:Fira Code .*|font pango:Fira Code 11|' "$I3CONF"
DUN="$TARGET_HOME/.config/dunst/dunstrc"
[ -f "$DUN" ] && run_as_user sed -i -E 's|^    font = Fira Code .*|    font = Fira Code 11|' "$DUN"
ROF="$TARGET_HOME/.config/rofi/config.rasi"
if [ -f "$ROF" ] && ! run_as_user grep -q 'font:' "$ROF"; then
    run_as_user sed -i 's|^configuration {|configuration {\n    font: "Fira Code 11";|' "$ROF"
fi
log_info "Bar/UI fonts sized for the 720p panel"

# The status bar (i3status) is shared by all installs and already includes the
# battery and the modem (shown as a network interface), so nothing to do here.

log_info "uConsole tweaks done. Reminder: apply the firmware-level prerequisites"
log_info "(ClockworkPi apt repo, /boot/firmware/config.txt overlays, CM5 EEPROM) — see README."
