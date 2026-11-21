#!/bin/sh
# Polkit authentication agent picker — execs the first agent binary found.
#
# The primary agent is Nix-shipped (home.nix `polkit_gnome`): HM's profile
# links libexec/, so the agent is at ~/.nix-profile/libexec/. The rest are
# fallbacks for distro-shipped agents (Debian 12's policykit-1-gnome, Arch,
# KDE, LXQt) so the probe also works on a foreign host.
#
# Fired by i3/config at startup:
#   exec --no-startup-id ~/.config/i3/scripts/polkit-agent.sh

for agent in \
  "$HOME/.nix-profile/libexec/polkit-gnome-authentication-agent-1" \
  /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
  /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
  /usr/lib/x86_64-linux-gnu/libexec/polkit-gnome-authentication-agent-1 \
  /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
  /usr/lib/x86_64-linux-gnu/polkit-kde-authentication-agent-1 \
  /usr/bin/lxpolkit
do
  [ -x "$agent" ] && exec "$agent"
done

echo "spumone: no polkit agent found — GUI privilege prompts disabled (home-manager switch, then relogin)" >&2
exit 1
