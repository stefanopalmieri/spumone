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
{ modulesPath, ... }:

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
  users.users.stefano = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "rehearsal"; # VM-only throwaway — never a real credential
  };

  # The real box is a minimal netinst; keep the guest equally spartan.
  environment.systemPackages = [ ];

  # Matches the hm repo's pin generation; NixOS warns on stateVersion drift.
  system.stateVersion = "25.05";
}
