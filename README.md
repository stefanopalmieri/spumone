# Lubuntu + Pi — Reproducible Setup with Nix + Home Manager

## What this gives you

- **Lubuntu** (LXQt) as the base OS
- **Emacs 30** + **Spacemacs** (vim editing style, vterm shell)
- **Pi** coding agent (installed via npm wrapper)
- **Starship** prompt (pastel powerline preset)
- **Firefox** + **Vimium** extension

## Initial setup (on a fresh Lubuntu install)

This repo is a **Nix flake** (no channels needed). It pins `nixpkgs-unstable`
and `home-manager` master via `flake.lock`, so every machine gets the same
packages. Nix itself is installed **multi-user** via the Determinate Systems
installer (systemd `nix-daemon`, flakes enabled by default).

> **Username is pinned to `stefano`.** `home.nix` (`home.username` /
> `home.homeDirectory = /home/stefano`) and `flake.nix`
> (`homeConfigurations.stefano`) are hardcoded. The fresh install's account
> must be `stefano` with home `/home/stefano`, or activation aborts. Using a
> different account? Change both files to match first.

### 1. Install Nix (Determinate, multi-user)
```bash
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### 2. Clone this repo
```bash
git clone <your-repo-url> ~/.config/home-manager
cd ~/.config/home-manager
```

### 3. Activate from the flake
The flake's `homeConfigurations.stefano` pins `home-manager` itself, so no
`home-manager` CLI or channels are required — build the activation package and
run it directly:
```bash
nix build .#homeConfigurations.stefano.activationPackage
./result/activate
```
Alternatively, invoke the pinned `home-manager` from the flake input:
```bash
nix run github:nix-community/home-manager -- switch --flake .#stefano
```

## Daily usage

From within `~/.config/home-manager`:
```bash
home-manager switch --flake .#stefano   # apply config changes
nix flake update                          # bump pinned nixpkgs / home-manager
home-manager switch --flake .#stefano     # rebuild with updated inputs
git add flake.lock && git commit -m "flake update"
```

### Post-activation one-offs (not managed by Home Manager)

These are outside Nix — re-run them once after activating on a fresh install:

- **Login shell**: use the **system** zsh, and **never** point your login shell
  at the Nix zsh:
  ```bash
  sudo apt install zsh     # system zsh at /usr/bin/zsh (listed in /etc/shells)
  chsh -s /usr/bin/zsh     # NOT `chsh -s $(which zsh)` — that resolves to
                           # ~/.nix-profile/bin/zsh, a symlink into /nix/store
  ```
  Home Manager still manages your `~/.zshrc` / `~/.zshenv` (starship, aliases,
  Nix PATH); only the *login* shell needs to be the stable apt binary. Pointing
  the login shell into `/nix` is a **lockout trap**: that path isn't in
  `/etc/shells`, `nix-collect-garbage` can invalidate it, and wiping `/nix`
  (see the migration section) deletes your login shell out from under you — on
  the next boot neither the graphical session nor a TTY can start a shell.
- **i3 window manager**: Home Manager ships i3's *config*
  (`~/.config/i3/config`), the i3status config, and the rofi theme — but **not
  the `i3` binary**, which is apt-managed. On a fresh Lubuntu install i3 is
  not present, so SDDM's session dropdown won't list it (only Lubuntu / LXQt /
  openbox appear). Install it and confirm the session entry landed:
  ```bash
  sudo apt install i3        # pulls in i3-wm, which ships
                             # /usr/share/xsessions/i3.desktop
  ls /usr/share/xsessions/   # should now show i3.desktop
  ```
  Then log out; SDDM will offer **i3** (and **i3-with-shmlog**) in the session
  picker. After logging in, the i3 config's bare-name launches (rofi, picom,
  dunst, firefox, emacs) resolve to the Nix-installed binaries — see the next
  bullet if any of them don't open.
- **Spacemacs**: `~/.emacs.d` bootstraps itself on first Emacs launch (HM only
  ships `.spacemacs`), so it regenerates automatically.
- **Apt-managed base**: the OS, system i3/X server/login manager, and any apt
  packages (e.g. the Chrome `.deb`) are outside Nix — reinstall those
  separately on a true nuke.
- **SSH/GPG keys, browser profile, other dotfiles**: back these up separately;
  they are not declared in `home.nix`.
- **Verify Nix apps launch from i3**: after logging into the i3 session, confirm
  `$mod+d` (rofi) and `$mod+b` (firefox) actually open. i3 itself is apt-managed,
  but it launches rofi/picom/dunst/firefox/emacs by bare name, so those
  Nix-installed binaries must be on the *graphical session* PATH. If nothing
  happens, your display manager isn't putting `~/.nix-profile/bin` on PATH —
  make sure it sources `~/.profile`, or add `export PATH="$HOME/.nix-profile/bin:$PATH"`
  to `~/.xprofile`.

## Notes

- **Pi**: Not in nixpkgs, so it's installed via an npm wrapper script at `~/.local/bin/pi`
- **Starship**: Config is supplied as raw TOML via `xdg.configFile` (`starship.toml`)
- **NUR**: no longer used; the `nur` channel is not required
- **Spacemacs layers**: emacs-lisp, helm, multiple-cursors, shell (vterm), treemacs
- **Shell sourcing**: `home.nix` (`programs.zsh.envExtra`) and `~/.profile` both
  source either the multi-user `nix-daemon.sh` or the single-user `nix.sh`, so
  the config works on either install style
- **QTerminal color scheme**: `Spacemacs.colorscheme` is shipped via
  `xdg.dataFile` to `~/.local/share/qterminal/color-schemes/`, **not** beside
  `qterminal.ini`. QTerminal's `MainWindow::setupCustomDirs()` discovers user
  schemes two ways: (1) `QStandardPaths::locateAll(GenericDataLocation,
  "qterminal")` → `~/.local/share/qterminal/color-schemes/`, and (2)
  `QFileInfo(qterminal.ini).canonicalPath() + "/color-schemes"` → the dir
  beside the ini. Home Manager symlinks `qterminal.ini` into `/nix/store`, so
  mechanism (2) resolves through the symlink to `/nix/store` and that dir never
  exists — a scheme placed beside the ini is silently never registered and
  QTerminal falls back to its built-in **white-background** default. Mechanism
  (1) is independent of the ini symlink, so the scheme is reliably found under
  `$XDG_DATA_HOME`. If QTerminal ever launches with a white background after a
  rebuild, this is why.

## Migrating from a legacy single-user + channels install

The machine currently has the old `curl ... | sh` single-user Nix (no
`nix-daemon`, `/nix/store` owned by the user, channels in `~/.nix-channels`).
This section converts it to the flake + Determinate multi-user setup above.

The uninstall/reinstall is **destructive** (it wipes `/nix` and all
generations) and needs `sudo`, so run it in your own terminal.

```bash
# 0. (Recommended) Push the repo to a private remote as a backup.
#    Your config lives outside /nix, so it survives the steps below either way.
cd ~/.config/home-manager
#    Set a real identity if the placeholder is still in place:
git config user.email "you@example.com"
git config user.name  "Your Name"
git remote add origin git@github.com:<you>/home-manager.git   # or https URL
git push -u origin main

# 1. CRITICAL: reset your login shell OUT of /nix before wiping it. If your
#    login shell still points at ~/.nix-profile/bin/zsh (or a /nix/store path),
#    the next step deletes it and you get locked out of every login (graphical
#    AND TTY). Use the apt-installed system zsh instead:
sudo apt install zsh
chsh -s /usr/bin/zsh          # or: chsh -s /usr/bin/bash
#    Confirm it took (should NOT contain /nix):
getent passwd "$USER" | awk -F: '{print $NF}'

# 2. Uninstall the legacy single-user Nix (wipes /nix and all generations).
#    ~/.config/home-manager is untouched.
sudo rm -rf /nix /etc/nix \
  ~/.nix-profile ~/.nix-defexpr ~/.nix-channels \
  ~/.local/state/nix

# 3. Install Nix multi-user via Determinate (flakes enabled by default).
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install

# 4. Load Nix into this shell.
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 5. Rebuild everything from the pinned flake — no channels, no home-manager
#    CLI needed.
cd ~/.config/home-manager
nix build .#homeConfigurations.stefano.activationPackage
./result/activate
```

After step 5, all packages, `.spacemacs`, starship, i3/rofi/i3status configs,
zsh, etc. come back exactly as they were (pinned to the same nixpkgs commit).
`~/.nix-profile` becomes a per-user profile under
`/nix/var/nix/profiles/per-user/stefano/` instead of the old single-user
location.

If the Determinate installer complains about leftover `/nix`, re-run the
`rm -rf` in step 1 (some files under `/nix/store` may be root-owned in odd
cases — `sudo rm -rf /nix` handles it).

> **Status note (as of this commit):** the repo's git identity is a placeholder
> (`stefano <stefano@localhost>`) and no remote is configured yet, so step 0 is
> currently blocked. The config is safe on disk regardless. Finish step 0 as
> soon as GitHub access is available.

## Other things you might want to add

### Development
- **direnv** — load per-project environment variables automatically. Great for nix-shell or per-project tool versions. `programs.direnv.enable = true;`
- **fzf** — fuzzy finder, integrates with bash/emacs. `programs.fzf.enable = true;`
- **zoxide** — smarter `cd` command that learns your habits. `programs.zoxide.enable = true;`
- **lazygit** — terminal UI for git. `programs.lazygit.enable = true;`
- **neovim** — as a lightweight emacs alternative for quick edits. `programs.neovim.enable = true;`
- **tmux** — terminal multiplexer, pairs well with emacs. `programs.tmux.enable = true;`

### System tools
- **alacritty** or **wezterm** — GPU-accelerated terminal emulators. `programs.alacritty.enable = true;`
- **fish** or **zsh** — alternative shells with better defaults. `programs.fish.enable = true;`
- **btop** — modern system monitor (better htop). Add to `home.packages`.

### Emacs enhancements
- **emacs-overlay** — nix-community's Emacs overlay for bleeding-edge versions. Useful if you want emacs31/git builds.
- **tree-sitter** grammars — for better syntax highlighting in emacs.

### Desktop
- **rofi** — application launcher (replaces Lubuntu's default). `programs.rofi.enable = true;`
- **dunst** — lightweight notification daemon. `services.dunst.enable = true;`
- **feh** — set wallpapers from command line. Add to `home.packages`.
- **flameshot** — screenshot tool. Add to `home.packages`.

### Networking
- **openssh** — SSH client config. `programs.ssh.enable = true;`
- **mosh** — mobile SSH (persistent connections over UDP). Add to `home.packages`.

### Secrets management
- **gnupg** — GPG key management. `programs.gpg.enable = true;`
- **password-store** — `pass` password manager. `programs.password-store.enable = true;`
- **sops** — encrypted secrets in git. Great for managing API keys declaratively.

### Nix-specific
- **Flakes** — pin nixpkgs to a specific version for full reproducibility. Add a `flake.nix` to lock inputs.
- **agenix** or **sops-nix** — declarative secret management for NixOS/Home Manager.
- **nix-index** — quickly find which nixpkg provides a file. `programs.nix-index.enable = true;`
- **nh** — nice helper for nix commands (`nh os switch`, `nh home switch`). Add to `home.packages`.
