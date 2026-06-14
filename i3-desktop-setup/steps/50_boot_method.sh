# shellcheck shell=bash disable=SC2016
#
# 50_boot_method.sh — configure how the desktop starts.
# (SC2016: the literal $HOME/$DISPLAY in the .bash_profile snippet is intentional.)
#   lightdm (default): graphical login screen.
#   startx           : console autologin on tty1 -> startx -> i3.
# Sourced by install.sh.

log_step "Configuring boot method: $BOOT_METHOD"

AUTOLOGIN_DROPIN="/etc/systemd/system/getty@tty1.service.d/override.conf"

if [ "$BOOT_METHOD" = "lightdm" ]; then
    log_info "Installing LightDM display manager"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        lightdm lightdm-gtk-greeter arc-theme papirus-icon-theme
    sudo systemctl enable lightdm
    sudo systemctl set-default graphical.target

    # Force the GTK greeter (some Pi/uConsole images default to pi-greeter, which
    # ignores lightdm-gtk-greeter.conf and stays unstyled).
    sudo install -d -m 0755 /etc/lightdm/lightdm.conf.d
    sudo tee /etc/lightdm/lightdm.conf.d/20-uconsole-greeter.conf >/dev/null <<'EOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
EOF

    # Theme the greeter to match the desktop: dark theme, Papirus icons and the
    # synthwave wallpaper (copied to a system path the lightdm user can read).
    sudo install -D -m 0644 "$REPO_DIR/config/wallpaper/futuristic.png" \
        /usr/share/backgrounds/uconsole-futuristic.png
    sudo cp -n /etc/lightdm/lightdm-gtk-greeter.conf \
        /etc/lightdm/lightdm-gtk-greeter.conf.i3ds.bak 2>/dev/null || true
    sudo tee /etc/lightdm/lightdm-gtk-greeter.conf >/dev/null <<'EOF'
[greeter]
background = /usr/share/backgrounds/uconsole-futuristic.png
theme-name = Arc-Dark
icon-theme-name = Papirus-Dark
font-name = Fira Code 11
xft-antialias = true
xft-hintstyle = hintslight
indicators = ~spacer;~clock;~spacer;~session;~power
clock-format = %H:%M
position = 50%,center 55%,center
hide-user-image = true
EOF

    log_ok "LightDM enabled + greeter themed (Arc-Dark, synthwave background)."
else
    log_info "Configuring console autologin + startx on tty1"
    # systemd drop-in: log the target user in automatically on tty1.
    sudo install -d -m 0755 "$(dirname "$AUTOLOGIN_DROPIN")"
    sudo tee "$AUTOLOGIN_DROPIN" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${TARGET_USER} --noclear %I \$TERM
EOF
    sudo systemctl daemon-reload
    sudo systemctl set-default multi-user.target

    # Start X automatically — but ONLY on the physical tty1 and only when no X
    # is already running, so other VTs stay usable as an escape hatch.
    append_once "$TARGET_HOME/.bash_profile" '[ -f "$HOME/.profile" ] && . "$HOME/.profile"'
    append_once "$TARGET_HOME/.bash_profile" 'if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'
    log_ok "Autologin + startx configured (i3 launches from ~/.xinitrc)."
    log_info "Escape hatch: switch to another VT (Ctrl+Alt+F2) and remove $AUTOLOGIN_DROPIN to disable."
fi
