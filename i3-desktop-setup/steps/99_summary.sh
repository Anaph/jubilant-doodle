# shellcheck shell=bash
#
# 99_summary.sh — final report and next steps. Sourced by install.sh.

log_step "Done!"

cat <<EOF

  i3 desktop setup complete for user: $TARGET_USER

  Boot method : $BOOT_METHOD
  Theme       : $THEME (Alacritty + i3 palette)
  Claude Code : $([ "$INSTALL_CLAUDE" = 1 ] && echo "installed (~/.local/bin/claude)" || echo "skipped")

  How to start the desktop:
EOF

if [ "$BOOT_METHOD" = "lightdm" ]; then
    cat <<'EOF'
    - Reboot (`sudo reboot`) to reach the LightDM login screen, then pick the
      "i3" session and sign in.
    - Or start it now without rebooting:  sudo systemctl start lightdm
EOF
else
    cat <<'EOF'
    - Reboot (`sudo reboot`): tty1 logs in automatically and launches i3.
    - Or start it now from this console (on tty1):  startx
EOF
fi

cat <<'EOF'

  First steps inside i3:
    - Super+Return            open Alacritty (Super+Shift+Return = xterm fallback)
    - Super+d                 application launcher (rofi)
    - Super+Shift+e           exit i3
    - Super+Shift+x           lock screen
    See ~/.config/i3/config for the full keybinding list.

  Claude Code:
    Open a new terminal (so the PATH update takes effect) and run `claude` to
    sign in. If `claude` is not found, run:  source ~/.profile

  If Alacritty shows a black window or a GL/EGL error on the Pi:
    Edit ~/.xsessionrc (lightdm) or ~/.xinitrc (startx) and uncomment
    `export LIBGL_ALWAYS_SOFTWARE=1`, then restart the session.

EOF

log_info "Uninstall:  $REPO_DIR/uninstall.sh   (add --purge to also remove apt packages)"
log_ok "Enjoy your i3 desktop!"
