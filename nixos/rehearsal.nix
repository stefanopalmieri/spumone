# NixOS rehearsal VM — the on-ramp to the eventual full-Nix migration.
#
# NOT the real machine: this boots in qemu (`nix build
# .#nixosConfigurations.rehearsal.config.system.build.vm` then
# ./result/bin/run-rehearsal-vm) so the NixOS shape of this config is
# validated long before it touches real hardware. Iterate here, one step
# at a time; each milestone mirrors a piece of the Debian+HM split until
# nothing is left but NixOS.
#
# Step 1 (this commit): barebones boot — kernel, getty, one user. Deliberately
# WITHOUT Home Manager: prove the hypervisor path first, then wire hm in.
# The end state mirrors the Debian host:
#   just login-shell -> users.users.*.shell
#   just xorg        -> services.xserver/* + environment.systemPackages
#   just audio       -> services.pipewire
#   just startx      -> no display manager + lock-on-suspend unit
#   home.nix         -> home-manager.users.<name> (unchanged module)
{ modulesPath, lib, pkgs, ... }:

{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  # Headless rehearsal: serial console only (`-nographic`), no GPU pass-through
  # games. X (step 4+, if we get there) can use the qemu std vga via SDL.
  virtualisation.graphics = false;
  virtualisation.memorySize = 1024; # host has 3.7G total — don't starve it

  networking.hostName = "rehearsal";
  time.timeZone = "America/Chicago";

  # The rehearsal user mirrors the real one (home-manager wires into this
  # same attrset in a later step via users.users.<name>).
  # Step 3 — mirrors `just login-shell`, minus the trap: on NixOS the zsh
  # in /etc/shells IS the nix one (the profile is part of the system
  # closure, so the Debian-era GC/lockout argument doesn't apply).
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
  # Step 4: X userland — the `just xorg` mirror.
  # ----------------------------------------------------------------
  # Server + xinit + the tools ~/.xinitrc calls by name (setxkbmap; xmodmap
  # for i3's exec_always keys remap). On real hardware this layer becomes
  # services.xserver + videoDrivers; what's under test here is the userland
  # chain (xinitrc → i3 → bare-name execs), identical on both.
  # Xvfb smoke test: xinit "$HOME/.xinitrc" -- Xvfb :1 -screen 0 1280x800x24
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
  # Step 2: Home Manager — the UNCHANGED home.nix from the repo root.
  # ----------------------------------------------------------------
  # This is the payoff of the user/host threading: on NixOS the same module
  # attaches via home-manager.users.<name> + extraSpecialArgs, no edits.
  # useGlobalPkgs: one pkgs set (NixOS's) for system + home — the NixOS-way
  # replacement for the apt/HM split. backupFileExtension: the guest's
  # $HOME starts empty, but keep activations non-destructive anyway.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.extraSpecialArgs = { username = "stefano"; host = { }; };
  home-manager.users.stefano.imports = [ ../home.nix ];

  # ----------------------------------------------------------------
  # Step 5: audio — the `just audio` mirror.
  # ----------------------------------------------------------------
  # One declarative block replaces the whole apt dance (pipewire-audio
  # metapackage + manual `systemctl --user enable`): pipewire, wireplumber
  # and the pulse/alsa bridges, with user-session units wired by the module.
  # The i3 volume/mute keys (wpctl) talk to this. Smoke test needs a sound
  # device: run the VM with `-device intel-hda -device hda-duplex`.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # RT scheduling for the audio graph — the module pair NixOS docs show
  # alongside services.pipewire; without it wireplumber spams RTKit
  # "ServiceUnknown" and the graph runs unprivileged-nice.
  security.rtkit.enable = true;

  # Step 4b: polkit's system half — the agent registers with polkitd on the
  # system bus; without it the agent has nothing to talk to. (The Debian
  # recipe's agent-install half is the hm bin-wrap above.)
  security.polkit.enable = true;

  # ----------------------------------------------------------------
  # Step 6: startx semantics — no DM + lock-before-suspend.
  # ----------------------------------------------------------------
  # No-DM: nothing to do — NixOS enables no display manager unless asked,
  # so the netinst "pre-ticked GNOME" trap cannot exist; getty owns tty1
  # and hm's .zlogin loginExtra startx-guards the rest, unchanged.
  #
  # lock-on-suspend: the Debian unit (startx/lock-on-suspend.service) as a
  # first-class NixOS unit — same Before/RequiredBy sleep.target choreography
  # and forking i3lock in Spacemacs bg1. Deltas: User is declarative (no
  # __USER__ sed), i3lock resolves from the closure (no /usr/bin on NOS),
  # and %h becomes the literal home (keep it in sync if the username ever
  # changes; rehearsal is single-user by construction).
  systemd.services.lock-on-suspend = {
    description = "Lock screen before suspend (startx, no DM)";
    before = [ "sleep.target" ];
    requiredBy = [ "sleep.target" ];
    environment = {
      DISPLAY = ":0";
      XAUTHORITY = "/home/stefano/.Xauthority";
    };
    serviceConfig = {
      Type = "forking";
      User = "stefano";
      ExecStart = "${pkgs.i3lock}/bin/i3lock -c 292b2e";
    };
  };

  # Matches the hm repo's pin generation; NixOS warns on stateVersion drift.
  system.stateVersion = "25.05";
}
