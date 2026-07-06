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
bootstrap: _sudo login-shell i3 vterm-deps spacemacs
    @echo ""
    @echo "✓ bootstrap complete."
    @echo "  Log out/in for the new login shell + i3 session to take effect."
    @echo "  Then launch Emacs once to install Spacemacs layers (incl. vterm)."
    @echo "  Finally run 'just verify-i3' after your first i3 login."

# Prime the sudo timestamp so the apt/chsh recipes below don't re-prompt.
_sudo:
    @sudo -v

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

# Install apt i3 (Home Manager ships the config, not the binary).
i3:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f /usr/share/xsessions/i3.desktop ]; then
      echo "i3 session entry already present — skipping"
      exit 0
    fi
    sudo apt install -y i3
    ls /usr/share/xsessions/i3.desktop

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
    @echo "After logging into the i3 session, verify:"
    @echo "  - \$mod+d opens the rofi app launcher"
    @echo "  - \$mod+b opens firefox"
    @echo "  - \$mod+Return opens a terminal"
    @echo ""
    @echo "If nothing happens, the display manager isn't putting"
    @echo "~/.nix-profile/bin on the graphical PATH."
    @echo "Ensure it sources ~/.profile, or add to ~/.xprofile:"
    @echo '  export PATH="$HOME/.nix-profile/bin:$PATH"'
