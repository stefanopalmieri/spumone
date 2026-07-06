{ config, pkgs, ... }:

{
  home.username = "stefano";
  home.homeDirectory = "/home/stefano";
  home.stateVersion = "24.11";

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

    # i3 / desktop tooling (referenced by i3 config)
    rofi
    picom
    dunst
    feh
    flameshot
    redshift
    unclutter
    arandr
    pcmanfm
    playerctl
    brightnessctl
    i3lock
    i3status


    # Python package manager / environment (not in nixpkgs)
    (pkgs.stdenv.mkDerivation rec {
      pname = "uv";
      version = "0.11.24";
      src = pkgs.fetchurl {
        url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-x86_64-unknown-linux-gnu.tar.gz";
        sha256 = "1v8zqd7jwxj838am655wjlhjisqjbaw8n212h5f6rybq983svqaw";
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
  # Starship config — Pastel Powerline preset (raw TOML file)
  # ----------------------------------------------------------------
  xdg.configFile."starship.toml".source = ./starship.toml;

  # starship config is supplied as raw TOML via xdg.configFile above;
  # we don't use programs.starship.enable to avoid config conflict.

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
    initContent = ''
      # Load starship prompt
      if [[ $TERM != "dumb" ]]; then
        eval "$(${pkgs.starship}/bin/starship init zsh)"
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


  # ----------------------------------------------------------------
  # Terminal font + color scheme (QTerminal)
  # ----------------------------------------------------------------
  home.file.".config/qterminal.org/qterminal.ini".force = true;
  home.file.".config/qterminal.org/qterminal.ini".text = ''
    [General]
    fontFamily=SauceCodePro Nerd Font
    fontSize=14
    UseFontBoxDrawingChars=false
    colorScheme=Spacemacs
  '';

  # Spacemacs-themed color scheme for QTerminal
  # (background matches Spacemacs bg1 #292b2e)
  #
  # NOTE: This MUST live under $XDG_DATA_HOME (~/.local/share/qterminal/),
  # NOT next to qterminal.ini. QTerminal's MainWindow::setupCustomDirs()
  # discovers user color schemes two ways:
  #   1. QStandardPaths::locateAll(GenericDataLocation, "qterminal")
  #      -> ~/.local/share/qterminal/color-schemes  (used here)
  #   2. QFileInfo(settings.fileName()).canonicalPath() + "/color-schemes"
  #      -> the dir beside qterminal.ini
  # Home Manager symlinks qterminal.ini into /nix/store, so canonicalPath()
  # in (2) resolves to /nix/store (not ~/.config/qterminal.org), and that
  # custom dir never exists. A colorscheme shipped beside the ini is therefore
  # never registered and QTerminal silently falls back to its default
  # white-background scheme. Mechanism (1) is independent of the ini symlink,
  # so the scheme is reliably found here.
  xdg.dataFile."qterminal/color-schemes/Spacemacs.colorscheme".source =
    ./Spacemacs.colorscheme;

  # Nerd Fonts are installed via home.packages; enabling fontconfig here makes
  # fontconfig discover everything under the Home Manager profile's share/fonts,
  # so QTerminal / i3 / starship can resolve "SauceCodePro Nerd Font".
  # (Don't symlink a hardcoded /nix/store font path — it silently dangles
  # whenever the nerd-fonts package layout changes.)
  fonts.fontconfig.enable = true;

  programs.firefox = {
    enable = true;
    # Keep legacy profile path (silences configPath deprecation warning)
    configPath = ".mozilla/firefox";
  };

  # ----------------------------------------------------------------
  # i3 window manager config (system i3 on Lubuntu)
  # ----------------------------------------------------------------
  xdg.configFile."i3/config".force = true;
  xdg.configFile."i3/config".source = ./i3/config;
  xdg.configFile."i3/scripts/power-menu.sh".force = true;
  xdg.configFile."i3/scripts/power-menu.sh".source = ./i3/scripts/power-menu.sh;
  xdg.configFile."i3/scripts/cheatsheet.sh".force = true;
  xdg.configFile."i3/scripts/cheatsheet.sh".source = ./i3/scripts/cheatsheet.sh;

  # ----------------------------------------------------------------
  # Rofi theme (Spacemacs dark) for drun application picker
  # ----------------------------------------------------------------
  xdg.configFile."rofi/spacemacs.rasi".source = ./rofi/spacemacs.rasi;

  # ----------------------------------------------------------------
  # i3status bar config (Spacemacs dark theme)
  # ----------------------------------------------------------------
  xdg.configFile."i3status/config".force = true;
  xdg.configFile."i3status/config".source = ./i3status/config;

  # ----------------------------------------------------------------
  # Let Home Manager install and manage itself
  # ----------------------------------------------------------------
  programs.home-manager.enable = true;
}
