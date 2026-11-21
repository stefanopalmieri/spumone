# Post-activation setup for everything Home Manager can't manage.
#
# Run `just bootstrap` once on a fresh install after activating the Home
# Manager generation, or run individual recipes as needed. `just --list`
# prints the available recipes.
#
# The README holds the *why* behind each step (lockout traps, gotchas,
# rationale). This file holds the *commands*.

default: bootstrap

# Run all post-activation one-offs (sudo primed once; every recipe idempotent).
# Order matters: login-shell before startx (the auto-startx in .zlogin needs
# the system zsh as the login shell). The i3 binary and the polkit agent are
# NOT here — Home Manager ships both (see home.nix `home.packages`).
bootstrap: _sudo login-shell xorg audio startx vterm-deps spacemacs
    @echo ""
    @echo "✓ bootstrap complete."
    @echo "  Log out/in for the new login shell to take effect."
    @echo "  Then launch Emacs once to install Spacemacs layers (incl. vterm)."
    @echo "  Finally run 'just verify-i3' after your first i3 login."

# Prime the sudo timestamp so the apt/chsh recipes below don't re-prompt.
# Non-interactive first (NOPASSWD sudoers, CI, ssh without a tty — plain
# `sudo -v` demands a terminal there even when no password is needed);
# fall back to the interactive prompt only when a password is required.
_sudo:
    @sudo -n true 2>/dev/null || sudo -v

# Install system zsh and set it as login shell (NEVER the Nix zsh — see README).
login-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(getent passwd "$USER" | awk -F: '{print $NF}')" = /usr/bin/zsh ]; then
      echo "login shell already /usr/bin/zsh — skipping"
      exit 0
    fi
    sudo apt install -y zsh
    chsh -s /usr/bin/zsh
    echo "login shell set to /usr/bin/zsh"

# X server + xinit + xkb tools. A minimal Debian netinst ships none of these
# (no desktop task; Lubuntu's desktop metapackage used to provide them).
# ~/.xinitrc calls `startx` and `setxkbmap`, so both must be present before
# the startx flow works.
# Idempotent: skips if `startx` is already on PATH.
xorg:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v startx >/dev/null 2>&1; then
      echo "xorg/xinit already installed — skipping"
      exit 0
    fi
    sudo apt install -y xorg xinit x11-xkb-utils

# PipeWire audio stack. A minimal Debian netinst has no sound server at all,
# while the i3 volume/mute keys call `wpctl` (from the `wireplumber`
# package). `pipewire-audio` is Debian's metapackage pulling
# in pipewire + wireplumber + pipewire-pulse + pipewire-alsa (Ubuntu ships
# the same stack preinstalled, so this no-ops there too). `wpctl` itself
# ships from `wireplumber`, so we guard on it for idempotency.
# The user services are D-Bus / systemd-user activated; enabling them here
# means they come up with the user session on the next login (startx runs
# under the login shell, which already has a user manager from logind).
audio:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v wpctl >/dev/null 2>&1; then
      echo "pipewire/wireplumber already installed (wpctl present) — skipping"
      exit 0
    fi
    sudo apt install -y pipewire-audio
    systemctl --user enable pipewire pipewire-pulse wireplumber >/dev/null 2>&1 || true
    echo "pipewire-audio installed + user services enabled"

# OPTIONAL: NetworkManager. A netinst drives the wired NIC via ifupdown, and
# that keeps working — so this is NOT part of bootstrap. Run it when you want
# NM to manage links (wifi, hotplug). Afterwards delete the matching stanza
# from /etc/network/interfaces or the two will fight over the device.
net:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v nmcli >/dev/null 2>&1 && systemctl is-enabled NetworkManager >/dev/null 2>&1; then
      echo "NetworkManager already installed + enabled — skipping"
      exit 0
    fi
    sudo apt install -y network-manager
    sudo systemctl enable --now NetworkManager
    echo "NetworkManager enabled. Remove the matching stanza from"
    echo "/etc/network/interfaces so ifupdown and NM don't fight over the link."

# Replace the display manager with startx: install the suspend-lock service
# (so lid-close / suspend locks the screen) and disable whatever display
# manager is installed. The actual session launch is ~/.zlogin → startx →
# ~/.xinitrc → i3 (all managed by Home Manager); this recipe only handles
# the system-level pieces HM can't. No DM installed (minimal Debian
# netinst)? Every check below no-ops cleanly.
startx:
    #!/usr/bin/env bash
    set -euo pipefail
    # Install + enable the lock-on-suspend service, substituting the current
    # user into the template (User=__USER__) so the unit is never pinned to a
    # hardcoded account. Always regenerate — an existing wrong-user install
    # gets fixed on the next run, and `tee`/`chmod` are idempotent.
    sed "s/__USER__/$USER/" "$(pwd)/startx/lock-on-suspend.service" \
      | sudo tee /etc/systemd/system/lock-on-suspend.service >/dev/null
    sudo chmod 644 /etc/systemd/system/lock-on-suspend.service
    sudo systemctl daemon-reload
    sudo systemctl enable lock-on-suspend.service >/dev/null 2>&1 || true
    echo "lock-on-suspend.service installed + enabled (User=$USER)"
    # Disable any display manager so boot lands at the tty1 login prompt
    # (auto-startx). Not just sddm: the netinst's pre-ticked desktop task
    # ships gdm3, which otherwise owns tty1 and shadows the getty.
    for dm in gdm3 sddm lightdm lxdm slim xdm nodm; do
      if systemctl is-enabled "$dm" >/dev/null 2>&1; then
        sudo systemctl disable "$dm"
        echo "$dm disabled"
      fi
    done

# Install C toolchain (build-essential + cmake) + libvterm headers for
# Spacemacs's vterm layers. We use APT (not Nix) for cmake here because the
# Nix cmake links librhash.so, whose MD5 routine is built with SSE4.1 `pinsrd`
# — this machine's Core 2 Duo (SSSE3 max) crashes with SIGILL on it.
# libvterm-dev gives vterm.h + libvterm.so in /usr so cmake's find_path wins
# without downloading/building libvterm from source.
vterm-deps:
    sudo apt install -y build-essential cmake libvterm-dev

# Clone Spacemacs into ~/.emacs.d (Home Manager only ships ~/.spacemacs).
spacemacs:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f ~/.emacs.d/init.el ]; then
      echo "~/.emacs.d already has Spacemacs (init.el present) — skipping"
      exit 0
    fi
    rm -rf ~/.emacs.d
    git clone -b develop https://github.com/syl20bnr/spacemacs ~/.emacs.d
    echo "Spacemacs cloned — launch Emacs to bootstrap layers on first run"

# Print manual post-login checks to run after your first i3 login.
verify-i3:
    @echo "After logging into the i3 session (startx from tty1), verify:"
    @echo "  - \$mod+d opens the rofi app launcher"
    @echo "  - \$mod+b opens chromium"
    @echo "  - \$mod+Return opens a terminal (emacs vterm)"
    @echo "  - volume / mute keys work (wpctl — needs `just audio` first)"
    @echo "  - privileged actions pop a GUI password dialog (the polkit"
    @echo "    agent is Nix-shipped; see home.nix home.packages)"
    @echo ""
    @echo "If bare-name launches (rofi/chromium/emacs) fail, ~/.xinitrc"
    @echo "isn't putting ~/.nix-profile/bin on PATH. It sources"
    @echo "~/.nix-profile/etc/profile.d/nix.sh before `exec i3`;"
    @echo "check that the profile exists and that line ran."
    @echo "(This is the startx path — there is no display manager to"
    @echo "sanitize PATH, and ~/.xprofile is not read.)"
    @echo ""
    @echo "If volume keys do nothing, the PipeWire stack is missing —"
    @echo "run `just audio`."
