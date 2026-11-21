# `lenovo` — the real machine. Same shape as rehearsal.nix; the deltas are
# hardware (lenovo-hardware.nix), the lowres host trait, and NetworkManager
# instead of a wired-only assumption. The migration runbook is
# nixos/MIGRATION.md — read it before touching the machine.
{ lib, pkgs, ... }:

{
  imports = [
    ./lenovo-hardware.nix
    ./desktop-common.nix
  ];

  networking.hostName = "lenovo";
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # UEFI + systemd-boot; the ESP carries kernels (see lenovo-hardware.nix).
  # The installer re-registers the entry; old Debian GRUB bits die with the
  # ESP reformat in MIGRATION.md step 4.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Haswell CPU microcode + the firmware set (ath9k needs none — in-tree —
  # but the option is cheap and future-proof).
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # X for the startx flow: server + the hm-managed xinitrc chain, no DM —
  # displayManager.startx keeps NixOS's hands off session startup exactly
  # like `just startx` did on Debian (the .zlogin guard fires startx).
  services.xserver = {
    enable = true;
    videoDrivers = [ "modesetting" ]; # Haswell intel gfx; i915 KMS
  };
  services.xserver.displayManager.startx.enable = true;
  services.libinput.enable = true; # the touchpad, with palm detection

  # Userland tools the xinitrc/i3 call by name that the xserver module
  # doesn't pull in (mirrors rehearsal's list).
  environment.systemPackages = with pkgs; [
    xorg.xinit
    xorg.xmodmap
  ];

  networking.networkmanager.enable = true; # wifi: ar9485, in-tree ath9k

  # Same unfree discipline as rehearsal.nix: with useGlobalPkgs the hm
  # predicate is inert; NixOS owns nixpkgs.config.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem
    (lib.getName pkg) [ "bws" ];

  # Mirror `just login-shell`: system zsh in /etc/shells + login shell.
  programs.zsh.enable = true;
  users.users.stefano = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "networkmanager" "video" ];
    # One-boot throwaway: MIGRATION.md step 6 says `passwd` right after
    # first login. Never a real credential in git.
    initialPassword = "rehearsal";
    shell = pkgs.zsh;
  };

  # ----------------------------------------------------------------
  # Home Manager — the UNCHANGED home.nix, with the lenovo trait.
  # ----------------------------------------------------------------
  # host = { lowres = true; } is the SAME trait homeConfigurations
  # .stefano-lenovo carries: 1000x700 floating cap + centered dialogs for
  # the 1366x768 panel. One host attrset, hm and NixOS agree.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.extraSpecialArgs = {
    username = "stefano";
    host = { lowres = true; };
  };
  home-manager.users.stefano.imports = [ ../home.nix ];

  system.stateVersion = "25.05"; # the cutover release; do not bump casually
}
