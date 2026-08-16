# Spumone Space Program — Reproducible Lubuntu + Pi via Nix + Home Manager

Welcome aboard the **Spumone Space Program**.

This repository freeze-dries a complete Lubuntu workstation into a portable,
reproducible Home Manager flake. Think of it as astronaut ice cream: all the
flavor of a hand-tuned desktop, stripped of moisture and mystery, ready to
reconstitute on any fresh Lubuntu install.

## Flavor profile

- **Base**: Lubuntu (LXQt)
- **Mission control**: Emacs 30 + Spacemacs, evil-mode (vim-style), with vterm + ghostel terminals
- **Onboard AI**: Pi coding agent (npm wrapper)
- **Helmet HUD**: Starship prompt, spumone powerline theme
- **Alignment**: Chaotic Evil. `hjkl` or die.
- **Viewport**: Firefox + Vimium
- **Launch**: `startx` from tty1 — no display manager. `.zlogin`
  auto-fires `startx` on login (one password, lands straight in i3);
  `~/.xinitrc` sources the Nix profile and `exec i3`.

The palette is Spacemacs-dark gelato: purple `#5d4d7a`, blue `#4f97d7`,
magenta `#bc6ec5`, on a near-black `#292b2e` cone. Ghostly terminals
flicker in the purple glow — ghostel channels the specter of Ghostty's VT
engine from beyond the veil.

## Flying Debian instead of Lubuntu

This config is distro-agnostic by design — Nix owns user-space, apt owns a
handful of system binaries, and the Justfile glues them. It reconstitutes on
Debian with essentially no logic changes. The deltas:

- **Skip the desktop task.** A minimal Debian netinst has no LXQt/SDDM, so
  there's nothing to disable — `just startx`'s SDDM check no-ops cleanly, and
  boot lands at the tty1 getty prompt by default.
- **Install X yourself.** Lubuntu ships `xorg`/`xinit`/`xkb-utils` via its
  desktop metapackage; Debian minimal does not. `just xorg` (run before
  `startx`) installs `xorg xinit x11-xkb-utils` — needed by `~/.xinitrc`
  (`startx`, `setxkbmap`).
- **Network + polkit + audio.** A minimal Debian may ship plain `ifupdown`
  instead of NetworkManager; won't have `policykit-1-gnome` (the i3 config
  launches `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1` —
  same path on Debian); and won't ship PipeWire (the i3 volume/mute keys call
  `wpctl`, which comes from the `wireplumber` package). Install what you
  want: `sudo apt install network-manager policykit-1-gnome` for the tray
  applet + polkit prompts, and `just audio` (installs the `pipewire-audio`
  metapackage and enables the user services) for working volume keys. `audio`
  is part of `bootstrap`, so the sound stack is covered automatically;
  `network-manager` / `policykit-1-gnome` remain optional manual installs.
- **Same apt names.** `zsh`, `i3`, `build-essential`, `cmake`, `libvterm-dev`
  are identical on Debian — no recipe edits needed.
- **Core 2 Duo SIGILL workaround stays.** The Nix-`cmake`→librhash→SSE4.1
  `pinsrd` crash is CPU-arch-specific, not distro-specific. Keep using apt
  `cmake` via `just vterm-deps`.
- **Username is parametric.** `home.nix` no longer hardcodes a user —
  `username` is threaded in from `flake.nix` via `extraSpecialArgs`, so the
  same module works for any account. To fly under a different callsign, add
  one line (`homeConfigurations.bob = mkHome "bob";`) and activate with
  `--flake .#bob`. The lock-on-suspend service templates `User=__USER__`,
  substituted by `just startx` from `$USER` — no per-user edits needed.

So the Debian pre-flight is the Lubuntu one plus `just xorg` and `just audio`
(both already in `bootstrap`) and the optional `network-manager` /
`policykit-1-gnome` apt installs.

## Pre-flight checklist (fresh Lubuntu install)

This repo is a **Nix flake** — no channels needed. It pins `nixpkgs-unstable`
and `home-manager` master in `flake.lock`, so every capsule gets the same
freeze-dried packages. Nix itself installs **multi-user** via the Determinate
Systems installer (systemd `nix-daemon`, flakes enabled by default).

> **Crew manifest is parametric.** `home.nix` is user-agnostic — it takes
> `username` via `extraSpecialArgs` from `flake.nix`'s `mkHome` helper. The
> flake exposes `homeConfigurations.stefano = mkHome "stefano"`; activate with
> `home-manager switch --flake .#stefano` (or just `--flake .` when run as
> `stefano`, since home-manager defaults the config name to `$USER`). Flying
> under a different callsign? Add `homeConfigurations.<name> = mkHome
> "<name>";` to `flake.nix` — the home module, the lock-on-suspend service
> (via `just startx`), and `home.sessionPath` all pick up the new user with no
> further edits. (Named outputs rather than `$USER` at eval time because pure
> flake evaluation can't read the environment — `builtins.getEnv "USER"`
> returns empty without `--impure`, which we don't want to require.)
>
> **Host-specific tweaks via per-host outputs.** `mkHome` takes a `host`
> attrset of traits (threaded in as `extraSpecialArgs.host`) that opts into
> machine-specific tweaks. Pure flake eval can't read the hostname, so each
> host gets its own named output rather than auto-detecting at eval time.
> An attrset (rather than a boolean flag) ages better — adding a new trait
> is just a new key + snippet, with no new output plumbing. Each trait maps
> to a tweak snippet appended to the base i3 config. Currently:
>
> - `homeConfigurations.stefano` — base config (`mkHome "stefano" {}`).
> - `homeConfigurations.stefano-x61` — base + the `lowres` trait
>   (`mkHome "stefano" { lowres = true; }`), which appends `i3/lowres.conf`
>   (`floating_maximum_size 1000 x 700` + centered dialogs) so file-chooser
>   / print dialogs fit the ThinkPad X61's 1024×768 panel.
>
> Activate on the X61 with `home-manager switch --flake .#stefano-x61`; on
> higher-res hosts keep using `.#stefano` and the cap won't apply. To support
> another host, add `homeConfigurations.<name> = mkHome "<name>" { ... };` to
> `flake.nix` with the relevant traits. To add a new trait, add a key to the
> `host` attrset and a matching `optionalString` + snippet file in
> `home.nix` (e.g. `host.hidpi` → `i3/hidpi.conf`).
>
> Note: snippet files are read at pure-flake eval time via
> `builtins.readFile`, so any *new* snippet file must be `git add`-ed before
> `home-manager switch` can see it (an untracked file is invisible to the
> evaluator).

### 1. Install Nix (Determinate, multi-user)

```bash
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### 2. Clone the gelato capsule

```bash
git clone <your-repo-url> ~/.config/home-manager
cd ~/.config/home-manager
```

### 3. Activate from the flake

The flake's `homeConfigurations.stefano` pins Home Manager itself, so no
`home-manager` CLI or channels are required — build the activation package and
run it directly:

```bash
nix build .#homeConfigurations.stefano.activationPackage
./result/activate
```

Or invoke the pinned Home Manager from the flake input:

```bash
nix run github:nix-community/home-manager -- switch --flake .#stefano
```

## Daily flight ops

From `~/.config/home-manager`:

```bash
home-manager switch --flake .#stefano   # rehydrate config changes
nix flake update                          # refresh pinned inputs
home-manager switch --flake .#stefano     # rebuild with new inputs
git add flake.lock && git commit -m "flake update"
```

### Post-activation one-offs (outside the freezer)

Some steps are too chewy for Home Manager: system packages, login-shell
changes, and a writable git working tree. They are automated by a `Justfile`
(driven by [`just`](https://github.com/casey/just), which Home Manager
installs). After activating on a fresh install, run:

```bash
cd ~/.config/home-manager
just bootstrap
```

`just bootstrap` primes sudo once, then runs every recipe in order; each is
idempotent, so re-running after tweaks is safe. `just --list` prints the menu;
run `just verify-i3` after your first i3 login. The commands live in the
`Justfile`; the *why* behind each step is below.

- **`login-shell`** — installs the **system** zsh and sets it as the login
  shell. **Never** point the login shell at the Nix zsh
  (`~/.nix-profile/bin/zsh`): that binary is a symlink into `/nix/store`, is
  not in `/etc/shells`, can be garbage-collected, and gets deleted if `/nix`
  is wiped — locking you out of graphical and TTY logins. Home Manager still
  owns `~/.zshrc` / `~/.zshenv` (starship, aliases, Nix PATH); only the
  *login* shell must be the stable apt binary. (Run `chsh -s $(which zsh)` and
  you resolve to the nix symlink — a classic EVA leak.)
- **`i3`** — installs apt i3. Home Manager ships i3's *config*
  (`~/.config/i3/config`), the i3status config, and the rofi theme, but **not
  the `i3` binary**. The binary is needed by `~/.xinitrc` (`exec i3`). On a
  fresh Lubuntu install i3 is absent, so this lands `/usr/bin/i3` (plus a
  vestigial `/usr/share/xsessions/i3.desktop` that no display manager reads
  anymore — startx doesn't use xsessions). i3's config launches
  rofi/picom/dunst/firefox/emacs by bare name — see `verify-i3` if any hatch
  fails to open.
- **`startx`** — replaces the display manager with a `startx` flow:
  installs + enables `startx/lock-on-suspend.service` (so suspend / lid-close
  locks the screen, since there's no DM to re-prompt on resume) and disables
  SDDM so boot lands at the tty1 login prompt. The session launch itself —
  `.zlogin` → `startx` → `~/.xinitrc` → `i3` — is fully Home-Manager-managed
  (see `programs.zsh.loginExtra` and `home.file.".xinitrc"` in `home.nix`);
  this recipe only handles the system-level pieces HM can't.
- **`vterm-deps`** — installs `build-essential cmake libvterm-dev` (apt, **not**
  Nix) for Spacemacs's vterm/multivterm layers, which compile a C module
  against libvterm on first install. Home Manager does **not** ship a C
  compiler or `make` (those aren't user dotfiles). Crucially, the **Nix**
  `cmake` must be avoided on this machine: it links `librhash.so`, whose
  `rhash_md5_process_block` is built with the SSE4.1 `pinsrd` instruction,
  and this Core 2 Duo T7250 (SSSE3 max — no SSE4.1) executes it → `SIGILL`
  mid-configure (strace confirms `ILL_ILLOPN` inside `librhash.so.1`). cmake
  dies before writing a Makefile, so the subsequent `make` reports `No targets
  specified and no makefile found` — the visible symptom. The apt
  `/usr/bin/cmake` links the baseline-x86-64 glibc and works, so `cmake` and
  `libvterm-neovim` were removed from `home.nix`'s `home.packages` (only
  `libtool`, a shell wrapper with no SSE deps, stays). `libvterm-dev` puts
  `vterm.h` + `libvterm.so` under `/usr`, so vterm's `CMakeLists.txt`
  `find_path`/`find_library` pick it up directly (no vendored build, no
  `CMAKE_PREFIX_PATH` needed). Rebuild vterm after `home-manager switch` with
  `rm -rf build && cmake .. && cmake --build .` from the vterm package dir.
- **`spacemacs`** — clones Spacemacs into `~/.emacs.d`. Home Manager only ships
  the `~/.spacemacs` dotfile; the distribution is a writable working tree
  (downloads packages/cache at runtime), so it can't be a read-only Nix-store
  symlink. Spacemacs does **not** auto-bootstrap — a plain stub `~/.emacs.d`
  (just `auto-save-list/` / `eln-cache/`) means Emacs loads vanilla defaults
  and silently ignores `.spacemacs`. After cloning, launch Emacs once; on
  first run Spacemacs reads `~/.spacemacs`, installs the declared layers, and
  regenerates `~/.emacs.d` from there on.
- **`verify-i3`** — manual post-login checks (can't be automated): confirm
  `$mod+d` (rofi), `$mod+b` (firefox), `$mod+Return` (terminal/emacs vterm),
  and the volume/mute keys actually work after your first i3 login. i3 is
  apt-managed but launches rofi/picom/dunst/firefox/emacs by bare name, so
  those Nix-installed binaries must be on the session PATH. With `startx`
  this is handled by `~/.xinitrc`, which sources the Nix profile before
  `exec i3` — so the old display-manager PATH-sanitization footgun is gone.
  If bare-name launches fail, check that `~/.xinitrc`'s
  `~/.nix-profile/etc/profile.d/nix.sh` line ran (there is no DM and
  `~/.xprofile` is not read). If volume keys do nothing, run `just audio`.

### Not automated (manual EVA on a true nuke)

- **Apt-managed base**: the OS, system i3/X server/login manager, and any apt
  packages (e.g. the Chrome `.deb`) are outside Nix — reinstall those
  separately.
- **SSH/GPG keys, browser profile, other dotfiles**: back these up separately;
  they are not declared in `home.nix`.

## Orbital notes

- **Pi**: Not in nixpkgs, so it's installed via an npm wrapper script at
  `~/.local/bin/pi`.
- **No display manager**: boot lands at the tty1 getty login prompt (SDDM is
  disabled via `just startx`). `.zlogin` (`programs.zsh.loginExtra`) detects
  tty1 with no `$DISPLAY` and `exec startx`; `~/.xinitrc`
  (`home.file.".xinitrc"` → `startx/xinitrc`) sources the Nix profile, sets
  Caps↔Esc, and `exec i3`. `Mod+Shift+e` exits i3 → startx dies → shell dies
  → back at the login prompt. The chain fires **only on tty1**, so logging
  into tty2+ for debugging gives a plain shell (your failsafe console).
- **Suspend lock**: `startx/lock-on-suspend.service` runs `i3lock -c 292b2e`
  (Spacemacs `bg1`, matching the `$mod+Escape` i3 binding) before `sleep.target`.
  Installed + enabled by `just startx`. No DM means no auto re-prompt on
  resume, so this service is what keeps a closed lid locked. There is no
  auto-lock on manual VT-switch — hit `$mod+Escape` first.
- **Starship**: Config is supplied as raw TOML via `xdg.configFile`
  (`starship.toml`). The spumone palette (red → white → white → green → green)
  uses colors exclusively from nashamri/spacemacs-theme.
- **Spacemacs layers**: emacs-lisp, helm, multiple-cursors, shell (vterm),
  treemacs, ghostel.
- **Embrace the Evil**: `evil-ghostel` gives you `dd`, `ciw`, and `p` inside
  your terminal. If you only knew the power of the dark side.
- **Shell sourcing**: `home.nix` (`programs.zsh.envExtra`) and `~/.profile`
  source `nix-daemon.sh` (with a fallback to `nix.sh`) so `~/.nix-profile/bin`
  is on PATH.
- **Bar garnish**: i3bar has no native border, so a second 1px
  Spacemacs-purple (`#5d4d7a`) bar is stacked under the main bar, fed by an
  empty-status script. After changing bar blocks, use `i3-msg restart` (not
  `reload`) so the new bar process spawns.
- **QTerminal color scheme**: `Spacemacs.colorscheme` is shipped via
  `xdg.dataFile` to `~/.local/share/qterminal/color-schemes/`, **not** beside
  `qterminal.ini`. QTerminal's `MainWindow::setupCustomDirs()` discovers user
  schemes two ways: (1) `QStandardPaths::locateAll(GenericDataLocation,
  "qterminal")` → `~/.local/share/qterminal/color-schemes/`, and (2)
  `QFileInfo(qterminal.ini).canonicalPath() + "/color-schemes"` → the dir
  beside the ini. Home Manager symlinks `qterminal.ini` into `/nix/store`, so
  mechanism (2) resolves through the symlink to `/nix/store` and that dir
  never exists — a scheme placed beside the ini is silently never registered
  and QTerminal falls back to its built-in **white-background** default.
  Mechanism (1) is independent of the ini symlink, so the scheme is reliably
  found under `$XDG_DATA_HOME`. If QTerminal ever launches with a white
  background after a rebuild, this is why.

## Extra scoops to add

### Development
- **direnv** — load per-project environment variables automatically. Great
  for nix-shell or per-project tool versions. `programs.direnv.enable = true;`
- **fzf** — fuzzy finder, integrates with bash/emacs.
  `programs.fzf.enable = true;`
- **zoxide** — smarter `cd` command that learns your habits.
  `programs.zoxide.enable = true;`
- **lazygit** — terminal UI for git. `programs.lazygit.enable = true;`
- **tmux** — terminal multiplexer, pairs well with emacs.
  `programs.tmux.enable = true;`

### Emacs enhancements
- **emacs-overlay** — nix-community's Emacs overlay for bleeding-edge
  versions. Useful if you want emacs31/git builds.
- **tree-sitter** grammars — for better syntax highlighting in emacs.

### Networking
- **openssh** — SSH client config. `programs.ssh.enable = true;`
- **mosh** — mobile SSH (persistent connections over UDP). Add to
  `home.packages`.

### Secrets management
- **gnupg** — GPG key management. `programs.gpg.enable = true;`
- **password-store** — `pass` password manager.
  `programs.password-store.enable = true;`
- **sops** — encrypted secrets in git. Great for managing API keys
  declaratively.

### Nix-specific
- **agenix** or **sops-nix** — declarative secret management for NixOS/Home
  Manager.
- **nix-index** — quickly find which nixpkg provides a file.
  `programs.nix-index.enable = true;`
- **nh** — nice helper for nix commands (`nh os switch`, `nh home switch`).
  Add to `home.packages`.

---

*Buon volo*
