# The cutover installer: the GRAPHICAL NixOS ISO (GNOME + Calamares) with
# this repo aboard, wearing spumone. Built via
#   nix build .#nixosConfigurations.installer.config.system.build.isoImage
# and burned with dd (MIGRATION.md step 3). Boot it, follow MIGRATION.md.
#
# Two install paths, same image (MIGRATION.md):
#   A — reproducible CLI: terminal → partition per runbook →
#       nixos-install --flake /iso/nixos-config#lenovo
#   B — the Calamares menus (timezone/user/partition) for a gentle vanilla
#       install, then converge it: nixos-rebuild switch --flake …#lenovo
#
# Design notes:
# - The repo rides inside the ISO at /iso/nixos-config (a read-only store
#   copy via isoImage.contents — the ISO mounts at /iso, hence the prefix),
#   sourced from the flake itself, so the machine being installed can
#   ALWAYS see the exact committed config — no clone, no "which revision?".
#   Rebuild the ISO after any commit: it is a snapshot, not a link.
# - Network is required during install for the hm/nixpkgs inputs and
#   substitutes; ethernet preferred, else NetworkManager/nmtui.
# - Serial console stays wired (console=ttyS0 last) — rescue path when the
#   graphical session misbehaves on odd hardware.
{ modulesPath, lib, pkgs, self, config, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix")
  ];

  networking.hostName = "lenovo-installer";

  # ----------------------------------------------------------------
  # Dress code: spumone, not stock NixOS grey.
  # ----------------------------------------------------------------
  # ISO naming — the file is spumone-installer-*.iso, volume label
  # SPUMONE_INSTALL (the module asserts <= 32 chars and self-consistency).
  # mkForce: the cd-dvd profile pins baseName to its own default.
  isoImage.isoBaseName = lib.mkForce "spumone-installer";
  isoImage.volumeID = "SPUMONE_INSTALL";

  # The wallpaper: a quiet vertical fade of the Spacemacs bg (#292b2e →
  # near-black), committed as an asset so the ISO is reproducible without
  # image tooling in the closure.
  environment.etc."spumone-wallpaper.png".source = ./spumone-wallpaper.png;

  # GNOME defaults, spumone-flavoured: dark scheme, our wallpaper, and the
  # stock installer overrides (no tour, no idle blanking, no autosuspend)
  # re-declared here because mkForce must carry the whole value.
  services.desktopManager.gnome.extraGSettingsOverrides = lib.mkForce ''
    [org.gnome.shell]
    favorite-apps=[ 'firefox.desktop', 'nixos-manual.desktop', 'org.gnome.Console.desktop', 'org.gnome.Nautilus.desktop', 'gparted.desktop', 'calamares.desktop' ]
    welcome-dialog-last-shown-version='9999999999'
    [org.gnome.desktop.session]
    idle-delay=0
    [org.gnome.settings-daemon.plugins.power]
    sleep-inactive-ac-type='nothing'
    sleep-inactive-battery-type='nothing'
    [org.gnome.desktop.interface]
    color-scheme='prefer-dark'
    gtk-theme='Adwaita-dark'
    [org.gnome.desktop.background]
    picture-uri='file:///etc/spumone-wallpaper.png'
    picture-uri-dark='file:///etc/spumone-wallpaper.png'
    picture-options='zoom'
  '';
  services.desktopManager.gnome.extraGSettingsOverridePackages = [
    pkgs.gsettings-desktop-schemas
  ];

  # The spumone prompt, in the GNOME terminal too: the repo's starship theme
  # via STARSHIP_CONFIG, wired into interactive bash.
  environment.etc."starship.toml".text = builtins.readFile ../starship.toml;
  environment.variables.STARSHIP_CONFIG = "/etc/starship.toml";
  programs.bash = {
    enable = true;
    interactiveShellInit = ''
      if [[ $- == *i* ]]; then
        eval "$(${pkgs.starship}/bin/starship init bash)"
      fi
    '';
  };

  # Serial console last: kernel+systemd output AND a getty land on ttyS0 —
  # the rescue path if the graphical session misbehaves (the wayland
  # session on qemu's emulated GPU is the thing most likely to).
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  # Runbook tooling: sgdisk (partlabel renames), cryptsetup (open the
  # existing container — NEVER luksFormat, see MIGRATION.md), plus an
  # editor; starship carries the prompt (see above).
  environment.systemPackages = with pkgs; [
    git
    vim
    gptfdisk
    cryptsetup
    starship
  ];

  # The flake itself, frozen into the image.
  isoImage.contents = [
    {
      source = "${self}";
      target = "/nixos-config";
    }
  ];
}
