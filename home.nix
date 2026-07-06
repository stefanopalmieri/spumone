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

  # ----------------------------------------------------------------
  # LXQt theming — make the panel, menus, pcmanfm-qt, lxqt-runner, and
  # every Qt app pick up the Spacemacs-dark palette + SauceCodePro font.
  #
  # LXQt's appearance lives in ~/.config/lxqt/lxqt.conf:
  #   [General]  theme=        panel QSS/SVG theme
  #              icon_theme=   icon set
  #   [Palette]  *_color=       the QPalette applied to all Qt widgets
  #   [Qt]       font=         QFont::toString()  style=  Qt style
  # The palette keys below are exactly the ones lxqt-config-appearance
  # reads/writes (see styleconfig.cpp: window_color, base_color,
  # highlight_color, window_text_color, text_color, highlighted_text_color,
  # link_color, link_visited_color, tooltip_base_color, tooltip_text_color).
  #
  # Caveat: HM symlinks this file read-only, so the GUI Appearance config
  # won't be able to *save* palette changes back — edit home.nix instead.
  # (The palette file below is also shipped as a loadable palette so it
  # appears in the GUI's "Load Palette" list.)
  xdg.configFile."lxqt/lxqt.conf".force = true;
  xdg.configFile."lxqt/lxqt.conf".text = ''
    [General]
    __userfile__=true
    single_click_activate=false
    tool_button_style=ToolButtonTextBesideIcon
    # Dark panel QSS/SVG theme (closest to Spacemacs-dark).
    theme=dark
    # Dark icon set matching the panel — installed system-wide by Lubuntu.
    icon_theme=Papirus-Dark

    [Palette]
    # Spacemacs-dark: bg1=#292b2e, bg2=#2a2c31, fg=#b2b2b2,
    # blue=#4f97d7 (Color4, accent/selection), purple=#bc6ec5 (link-visited).
    window_color=#292b2e
    base_color=#2a2c31
    window_text_color=#b2b2b2
    text_color=#b2b2b2
    highlight_color=#4f97d7
    highlighted_text_color=#ffffff
    link_color=#4f97d7
    link_visited_color=#bc6ec5
    tooltip_base_color=#2a2c31
    tooltip_text_color=#b2b2b2

    [Qt]
    # QFont::toString() format: family,pointSize,pixelSize,weight,italic,…
    # Same shape as the Lubuntu default, family swapped to the Nerd Font
    # used by QTerminal + Spacemacs so the whole desktop matches.
    font="SauceCodePro Nerd Font,11,-1,5,50,0,0,0,0,0"
    doubleClickInterval=400
    style=Fusion
    wheelScrollLines=3
  '';

  # Loadable Spacemacs-dark palette for lxqt-config-appearance's
  # "Load Palette" dialog (lives in $XDG_DATA_HOME/lxqt/palettes/).
  xdg.dataFile."lxqt/palettes/Spacemacs".text = ''
    [Palette]
    base_color=#2a2c31
    highlight_color=#4f97d7
    highlighted_text_color=#ffffff
    link_color=#4f97d7
    link_visited_color=#bc6ec5
    text_color=#b2b2b2
    window_color=#292b2e
    window_text_color=#b2b2b2
    tooltip_base_color=#2a2c31
    tooltip_text_color=#b2b2b2
  '';

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
  xdg.configFile."i3/scripts/empty-status.sh".force = true;
  xdg.configFile."i3/scripts/empty-status.sh".source = ./i3/scripts/empty-status.sh;

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
