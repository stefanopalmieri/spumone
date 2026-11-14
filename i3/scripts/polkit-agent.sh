#!/bin/sh
# Polkit authentication agent picker — execs the first agent binary found.
#
# There is no canonical path: Debian 12's policykit-1-gnome lives in
# /usr/lib/policykit-1-gnome, Arch's polkit-gnome in /usr/lib/polkit-gnome,
# KDE's agent under the multiarch libexec dir, LXQt's lxpolkit in /usr/bin.
# Debian 13 (trixie) dropped policykit-1-gnome entirely — `just polkit`
# installs lxpolkit there; this probe finds either.
#
# Fired by i3/config at startup:
#   exec --no-startup-id ~/.config/i3/scripts/polkit-agent.sh

for agent in \
  /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
  /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
  /usr/lib/x86_64-linux-gnu/libexec/polkit-gnome-authentication-agent-1 \
  /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
  /usr/lib/x86_64-linux-gnu/polkit-kde-authentication-agent-1 \
  /usr/bin/lxpolkit
do
  [ -x "$agent" ] && exec "$agent"
done

echo "spumone: no polkit agent found — GUI privilege prompts disabled (run: just polkit)" >&2
exit 1
