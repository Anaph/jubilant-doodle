#!/usr/bin/env bash
#
# polkit-agent.sh — start whichever polkit authentication agent is installed.
# policykit-1-gnome was removed in Debian Trixie, so we prefer mate-polkit /
# lxpolkit and fall back to others. Without an agent, GUI privilege prompts
# (mounting, NetworkManager edits) cannot appear. A no-op if none is present.

for a in \
    /usr/lib/*/mate-polkit/polkit-mate-authentication-agent-1 \
    /usr/libexec/polkit-mate-authentication-agent-1 \
    /usr/bin/lxpolkit \
    /usr/bin/lxqt-policykit-agent \
    /usr/libexec/polkit-gnome-authentication-agent-1 \
    /usr/lib/*/polkit-gnome/polkit-gnome-authentication-agent-1; do
    if [ -x "$a" ]; then
        exec "$a"
    fi
done
