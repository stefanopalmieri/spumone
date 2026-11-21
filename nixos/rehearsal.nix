# NixOS rehearsal VM — the on-ramp to the full-Nix migration.
#
# NOT the real machine: this boots in qemu (`nix build
# .#nixosConfigurations.rehearsal.config.system.build.vm` then
# ./result/bin/run-rehearsal-vm) so the NixOS shape of this config is
# validated long before it touches real hardware. Milestones one commit
# apart live in the history; the desktop system halves now live in
# ./desktop-common.nix, shared with nixos/lenovo.nix — the VM and the real
# box differ only in hardware/user plumbing:
#
#   just login-shell -> programs.zsh + users.*.shell (no GC trap on NOS)
#   just xorg        -> the pkgs below (VM) / services.xserver (real hw)
#   just audio       -> services.pipewire + security.rtkit (common)
#   just polkit      -> security.polkit (common) + hm bin-wrap (user)
#   just startx      -> no DM + the lock unit (common)
#   home.nix         -> home-manager.users.<name> (the module, unchanged)
{ modulesPath, lib, pkgs, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
    ./desktop-common.nix
  ];

  # Headless rehearsal: serial console only (`-nographic`), no GPU games.
  # X smoke test: xinit "$HOME/.xinitrc" -- "$(command -v Xvfb) :1 ..." —
  # xinit needs an absolute server path, else "Unrecognized option".
  virtualisation.graphics = false;
  virtualisation.memorySize = 1024; # host has 3.7G total — don't starve it

  networking.hostName = "rehearsal";
  time.timeZone = "America/Chicago";

  # Mirrors `just login-shell`, minus the trap: on NixOS the zsh in
  # /etc/shells IS the nix one (the profile is part of the system closure,
  # so the Debian-era GC/lockout argument doesn't apply).
  # programs.zsh.enable is the `apt install zsh` equivalent — the system
  # zsh, /etc/shells, global env — NOT hm's per-user module.
  programs.zsh.enable = true;
  users.users.stefano = {
    isNormalUser = true;
    # audio: the host user is in it on Debian too; on NOS the seat uaccess
    # ACL usually covers /dev/snd, but a serial/no-seat session (and this
    # VM) doesn't get one — explicit group beats invisible perm failures.
    extraGroups = [ "wheel" "audio" ];
    password = "rehearsal"; # VM-only throwaway — never a real credential

    shell = pkgs.zsh;
  };

  # ----------------------------------------------------------------
  # X userland — the `just xorg` mirror (VM variant).
  # ----------------------------------------------------------------
  # Server + xinit + the tools ~/.xinitrc calls by name (setxkbmap; xmodmap
  # for i3's exec_always keys remap). The real machine gets these via
  # services.xserver instead — see lenovo.nix.
  environment.systemPackages = with pkgs; [
    xorg.xorgserver
    xorg.xinit
    xorg.setxkbmap
    xorg.xmodmap
  ];

  # useGlobalPkgs (below) makes the home.nix unfree predicate inert: with a
  # shared pkgs set, NixOS owns nixpkgs.config. Mirror the bws-only predicate
  # here — same narrow form, never a global allowUnfree.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem
    (lib.getName pkg) [ "bws" ];

  # ----------------------------------------------------------------
  # Home Manager — the UNCHANGED home.nix from the repo root.
  # ----------------------------------------------------------------
  # This is the payoff of the user/host threading: on NixOS the same module
  # attaches via home-manager.users.<name> + extraSpecialArgs, no edits.
  # useGlobalPkgs: one pkgs set (NixOS's) for system + home — the NixOS-way
  # replacement for the apt/HM split. backupFileExtension: keep activations
  # non-destructive.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.extraSpecialArgs = { username = "stefano"; host = { }; };
  home-manager.users.stefano.imports = [ ../home.nix ];

  # Matches the hm repo's pin generation; NixOS warns on stateVersion drift.
  system.stateVersion = "25.05";
}
