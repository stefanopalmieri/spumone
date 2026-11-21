{ config, pkgs, username, host, ... }:

{
  # `username` is injected by flake.nix (mkHome) via extraSpecialArgs so this
  # module is user-agnostic. The login account must match the flake output
  # you activate with (e.g. `home-manager switch --flake .#stefano`).
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  # bws (Bitwarden Secrets Manager CLI) is licensed unfree in nixpkgs; allow
  # just it by name instead of flipping allowUnfree on globally.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "bws" ];

  # Pi's standalone node/bin directory + ~/.local/bin (the pi wrapper lives
  # there; bash gets it from Debian's ~/.profile, but zsh — the login shell
  # and thus the whole GUI session — reads no .profile, so declare it).
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.local/share/pi-node/node-v22.23.1-linux-x64/bin"
  ];

  # ----------------------------------------------------------------
  # Packages
  # ----------------------------------------------------------------
  home.packages = with pkgs; [
    # Core
    git
    curl
    wget
    ripgrep
    fd

    # Bitwarden Secrets Manager CLI (secrets for agents/scripts; unfree, see
    # allowUnfreePredicate above)
    bws

    # Emacs with tree-sitter support (vterm handled by Spacemacs config)
    emacs

    # Build toolchain for Spacemacs's vterm/multivterm layers.
    # NOTE: cmake + libvterm-dev come from APT, NOT Nix (see Justfile
    # `vterm-deps`). The Nix `cmake` pulls in librhash.so, whose
    # rhash_md5_process_block is built with the SSE4.1 `pinsrd` instruction;
    # this machine's Core 2 Duo T7250 (SSSE3 max, no SSE4.1) executes it ->
    # SIGILL during configure, so vterm's build dies with "No targets and no
    # makefile". The apt /usr/bin/cmake links the baseline-x86-64 glibc and
    # works. libtool is kept here (it's a shell-script wrapper, no SSE deps).
    libtool

    # pinentry for gpg-agent passphrase prompts (also on PATH for gpg
    # processes started outside the agent's systemd unit). tty flavor: the
    # curses dialog dies with "Screen or window too small" under the agent;
    # plain-tty prompt works interactively AND in headless/daemon shells.
    pinentry-tty

    # Zig — needed to compile ghostel's native module from source.
    # Ghostel's compile-command already passes `-Dcpu=baseline` so it
    # won't emit SSE4.1 instructions on this Core 2 Duo T7250.
    zig

    # Terminal
    zsh
    starship

    # Node (needed for pi)
    nodejs

    # Nerd Font (for starship powerline glyphs)
    pkgs.nerd-fonts.sauce-code-pro

    # Misc utilities
    htop
    tree
    unzip
    jq
    fastfetch
    just   # task runner — drives the post-activation bootstrap (see Justfile)

    # i3 WM binary + polkit agent, both Nix-shipped (formerly `just i3` /
    # `just polkit`). ~/.xinitrc sources the Nix profile before `exec i3`,
    # and i3's startup execs the polkit-agent probe, which finds the agent
    # at ~/.nix-profile/libexec/ — no apt packages needed for either.
    i3
    polkit_gnome

    # i3 / desktop tooling (referenced by i3 config)
    # rofi is managed by programs.rofi (below) to support plugins like rofi-emoji
    picom
    dunst
    feh
    maim
    slop     # interactive region selection (used by maim -s)
    xclip    # clipboard integration for screenshots
    redshift
    unclutter
    arandr
    pcmanfm
    playerctl
    brightnessctl
    chromium
    i3lock
    i3status


    # Python package manager / environment (not in nixpkgs)
    (pkgs.stdenv.mkDerivation rec {
      pname = "uv";
      version = "0.13.8";
      src = pkgs.fetchurl {
        url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-x86_64-unknown-linux-gnu.tar.gz";
        sha256 = "sha256-Ws/ZF3z+zwv4dXjwWXKCFczIhDiJiPVfemUEG1c4fZE=";
      };
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ];
      installPhase = ''
        mkdir -p $out/bin
        cp uv $out/bin/uv
        cp uvx $out/bin/uvx
      '';
      # Completions require running the (now-patched) binary. autoPatchelfHook
      # normally runs via postFixupHooks *after* this string, so patch the
      # binaries explicitly first using the `autoPatchelf` helper it provides.
      postFixup = ''
        autoPatchelf -- $out/bin
        mkdir -p $out/share/zsh/site-functions
        $out/bin/uv generate-shell-completion zsh > $out/share/zsh/site-functions/_uv
      '';
    })
  ];

  # ----------------------------------------------------------------
  # Pi (npm package — not in nixpkgs)
  # ----------------------------------------------------------------
  home.file.".local/bin/pi".force = true;
  home.file.".local/bin/pi".source = pkgs.runCommand "pi-coding-agent" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    makeWrapper ${pkgs.nodejs}/bin/npx $out \
      --set-default npm_config_update_notifier false \
      --add-flags "@earendil-works/pi-coding-agent"
  '';

  # ----------------------------------------------------------------
  # Spacemacs dotfile (.emacs.d is left to Spacemacs' own bootstrap)
  # ----------------------------------------------------------------
  home.file.".spacemacs".force = true;
  home.file.".spacemacs".source = ./spacemacs/.spacemacs;

  # ----------------------------------------------------------------
  # Starship config — spumone powerline theme (raw TOML file)
  # ----------------------------------------------------------------
  xdg.configFile."starship.toml".source = ./starship.toml;

  # ----------------------------------------------------------------
  # startx entry point (no display manager — see startx/README refs)
  # ----------------------------------------------------------------
  # ~/.xinitrc is read by `startx`, which .zlogin auto-launches on tty1
  # (see programs.zsh.loginExtra). Sources the Nix profile so bare-name
  # launches (rofi/picom/dunst/emacs) resolve, sets Caps↔Esc early, then
  # `exec i3`. `force` overwrites the pre-HM manual ~/.xinitrc.
  home.file.".xinitrc".force = true;
  home.file.".xinitrc".source = ./startx/xinitrc;

  # ----------------------------------------------------------------
  # Zsh configuration (default shell)
  # ----------------------------------------------------------------
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      grep = "grep --color=auto";
      vim = "nvim";
      vi = "nvim";
    };
    history = {
      size = 10000;
      save = 10000;
      path = "$HOME/.zsh_history";
    };

    # Inline command suggestions (grey ghost text) from zsh-autosuggestions.
    # Color = Spacemacs-dark "faint" foreground (#686868) — subtle, on-theme.
    autosuggestion = {
      enable = true;
      highlight = "fg=#686868";
    };

    # Command/syntax coloring from zsh-syntax-highlighting.
    # Palette mapped to the Spacemacs-dark theme:
    #   red      #f2241f  (error / unknown token)    [Color1]
    #   blue     #4f97d7  (keywords / precommands)    [Color4]
    #   purple   #bc6ec5  (functions / aliases / cmds) [Spacemacs func face]
    #   green    #2d9574  (strings / paths)           [Spacemacs string face]
    #   magenta  #a45bad  (constants / globs / nums)  [Spacemacs const face]
    #   teal     #2aa1ae  (comments)                 [Spacemacs comment face]
    #   base fg  #b2b2b2  (separators / default)      [colorscheme Foreground]
    syntaxHighlighting = {
      enable = true;
      styles = {
        unknown-token      = "fg=#f2241f";
        reserved-word      = "fg=#4f97d7";
        precommand         = "fg=#4f97d7";
        alias              = "fg=#bc6ec5";
        builtin            = "fg=#bc6ec5";
        function           = "fg=#bc6ec5";
        command            = "fg=#bc6ec5";
        commandseparator   = "fg=#b2b2b2";
        redirection        = "fg=#bc6ec5";
        assign             = "fg=#bc6ec5";
        back-quoted-argument = "fg=#bc6ec5";
        path               = "fg=#2d9574";
        path_pathseparator = "fg=#2d9574";
        glob               = "fg=#a45bad";
        single-quoted-argument  = "fg=#2d9574";
        double-quoted-argument  = "fg=#2d9574";
        dollar-quoted-argument   = "fg=#2d9574";
        rc-quoted-argument       = "fg=#2d9574";
        arg-numeric         = "fg=#a45bad";
        boolean             = "fg=#a45bad";
        comment             = "fg=#2aa1ae";
      };
    };

    initContent = ''
      # Load starship prompt
      if [[ $TERM != "dumb" ]]; then
        eval "$(${pkgs.starship}/bin/starship init zsh)"
      fi

      # Vi keybindings for the shell (approach 1: zsh owns vi,
      # Evil stays out of the way inside Spacemacs vterm).
      bindkey -v

      # Keep familiar emacs-style C- bindings in vi insert mode
      # so they still work as muscle memory expects.
      bindkey -M viins '^A' beginning-of-line
      bindkey -M viins '^E' end-of-line
      bindkey -M viins '^K' kill-line
      bindkey -M viins '^U' backward-kill-line
      bindkey -M viins '^W' backward-kill-word
      bindkey -M viins '^R' history-incremental-search-backward
      bindkey -M viins '^P' up-history
      bindkey -M viins '^N' down-history
    '';

    # Auto-launch i3 via startx on the tty1 login (no display manager).
    # Fires only on tty1 with no existing X. `exec startx` replaces the
    # login shell, so when i3 exits (Mod+Shift+e) startx dies, the shell
    # dies, and you land back at the getty login prompt — a clean loop.
    # Keeps a real boot password (unlike auto-login), no DM weight, lands
    # straight in i3. The suspend-lock service handles suspend/lid-close.
    loginExtra = ''
      if [[ -z "''${DISPLAY-}" ]] && [[ $(tty) = /dev/tty1 ]]; then
        exec startx
      fi
    '';

    # Source Nix profile setup so ~/.nix-profile/bin is on PATH.
    # Multi-user (Determinate) installs use nix-daemon.sh; single-user
    # installs use ~/.nix-profile/etc/profile.d/nix.sh. Handle both.
    # (bash gets this from .profile; zsh needs it explicitly)
    envExtra = ''
      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
    '';
  };

  # ----------------------------------------------------------------
  # Neovim configuration
  # ----------------------------------------------------------------
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;
  };


  # Nerd Fonts are installed via home.packages; enabling fontconfig here makes
  # fontconfig discover everything under the Home Manager profile's share/fonts,
  # so i3 / starship can resolve "SauceCodePro Nerd Font".
  # (Don't symlink a hardcoded /nix/store font path — it silently dangles
  # whenever the nerd-fonts package layout changes.)
  fonts.fontconfig.enable = true;

  # ----------------------------------------------------------------
  # QTerminal font (Nerd Font for starship powerline glyphs)
  # Ghostel is the primary terminal, but QTerminal is kept as a
  # fallback and needs the Nerd Font to render starship correctly.
  # ----------------------------------------------------------------
  xdg.configFile."qterminal.org/qterminal.ini".force = true;
  xdg.configFile."qterminal.org/qterminal.ini".text = ''
    [General]
    HideTabBarWithOneTab=false
    TerminalTransparency=0
    version=1.4.0
    fontFamily=SauceCodePro Nerd Font
    fontSize=14
    UseFontBoxDrawingChars=false

    [MainWindow]
    ApplicationTransparency=0

    [Shortcuts]
    Paste%20Clipboard=Ctrl+Shift+V
  '';

  # ----------------------------------------------------------------
  # Default browser (Chromium) — replaces Firefox for all web links
  # ----------------------------------------------------------------
  xdg.mimeApps.defaultApplications = {
    "text/html" = "chromium.desktop";
    "text/xml" = "chromium.desktop";
    "application/xhtml+xml" = "chromium.desktop";
    "application/xml" = "chromium.desktop";
    "application/rss+xml" = "chromium.desktop";
    "application/rdf+xml" = "chromium.desktop";
    "x-scheme-handler/http" = "chromium.desktop";
    "x-scheme-handler/https" = "chromium.desktop";
    "x-scheme-handler/ftp" = "chromium.desktop";
    "x-scheme-handler/about" = "chromium.desktop";
    "x-scheme-handler/unknown" = "chromium.desktop";
  };

  # ----------------------------------------------------------------
  # i3 window manager config (system i3 from apt)
  # ----------------------------------------------------------------
  xdg.configFile."i3/config".force = true;
  # The base config is the raw ./i3/config file; host-specific tweak
  # snippets are appended based on the `host` attrset (threaded in
  # from flake.nix via extraSpecialArgs).  Each trait maps to a snippet:
  # currently `host.lowres` -> i3/lowres.conf (floating-window size cap
  # + centered dialogs for sub-HD panels, e.g. the X61's 1024x768).
  #
  # Gotcha: builtins.readFile is resolved at pure-flake eval time, so
  # any new snippet file must be `git add`-ed before `home-manager switch`
  # can see it (an untracked file is invisible to the evaluator).
  xdg.configFile."i3/config".text =
    builtins.readFile ./i3/config
    + pkgs.lib.optionalString (host.lowres or false)
        (builtins.readFile ./i3/lowres.conf + "\n");
  xdg.configFile."i3/scripts/power-menu.sh".force = true;
  xdg.configFile."i3/scripts/power-menu.sh".source = ./i3/scripts/power-menu.sh;
  xdg.configFile."i3/scripts/cheatsheet.sh".force = true;
  xdg.configFile."i3/scripts/cheatsheet.sh".source = ./i3/scripts/cheatsheet.sh;
  xdg.configFile."i3/scripts/empty-status.sh".force = true;
  xdg.configFile."i3/scripts/empty-status.sh".source = ./i3/scripts/empty-status.sh;
  xdg.configFile."i3/scripts/polkit-agent.sh".force = true;
  xdg.configFile."i3/scripts/polkit-agent.sh".source = ./i3/scripts/polkit-agent.sh;

  # ----------------------------------------------------------------
  # i3status bar config (Spacemacs dark theme)
  # ----------------------------------------------------------------
  xdg.configFile."i3status/config".force = true;
  xdg.configFile."i3status/config".source = ./i3status/config;

  # ----------------------------------------------------------------
  # Rofi application launcher + emoji plugin
  # Theme is the Spacemacs-dark rasi; theme is managed here so Home Manager
  # can set up plugin paths for rofi-emoji automatically.
  # ----------------------------------------------------------------
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = ./rofi/spacemacs.rasi;
    plugins = [ pkgs.rofi-emoji ];
  };

  # ----------------------------------------------------------------
  # Secrets & keys: pass (password store) on GnuPG
  # ----------------------------------------------------------------
  # pass is the CLI password manager: each secret is an encrypted file in
  # ~/.password-store, the store itself is a git repo, and everything is
  # driven from the terminal (see `pass --help`). GnuPG agent caches the
  # key passphrase in the session; pinentry-curses prompts in the tty.
  programs.password-store.enable = true;

  # GnuPG itself (the agent below prompts via pinentry-curses in the tty).
  # The GitHub SSH key stays a plain ed25519 file, used agentless: no
  # passphrase, and at-rest risk is covered by the LUKS-encrypted disk.
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-tty;
    # HM's unit does not put pinentry on the agent's PATH, so name it
    # explicitly -- otherwise the agent dies with "No pinentry".
    extraConfig = ''
      pinentry-program ${pkgs.pinentry-tty}/bin/pinentry-tty
    '';
    defaultCacheTtl = 86400; # ask at most once a day
    maxCacheTtl = 86400;
  };

  # ----------------------------------------------------------------
  # Let Home Manager install and manage itself
  # ----------------------------------------------------------------
  programs.home-manager.enable = true;
}
