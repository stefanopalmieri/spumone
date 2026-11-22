# The cutover installer: a minimal NixOS installation ISO carrying this
# repo. Built via
#   nix build .#nixosConfigurations.installer.config.system.build.isoImage
# and burned with dd (MIGRATION.md step 3). Boot it, follow MIGRATION.md.
#
# Design notes:
# - The repo rides inside the ISO at /iso/nixos-config (a read-only store
#   copy via isoImage.contents — the ISO mounts at /iso, hence the prefix),
#   sourced from the flake itself, so the machine being installed can
#   ALWAYS see the exact committed config — no clone, no "which revision?".
# - Network is still required during nixos-install for the hm/nixpkgs
#   flake inputs and package substitutes; ethernet preferred, else
#   `wpa_passphrase` + this image's wpa_supplicant. A fully offline
#   closure-baked ISO is a documented non-goal for now (MIGRATION.md).
# - The partitioning tools the runbook names-checks with live here, so the
#   "tool missing" failure mode is designed out.
{ modulesPath, pkgs, self, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  networking.hostName = "lenovo-installer";
  # Serial console last: kernel+systemd output AND a getty land on ttyS0,
  # so the image is scriptable/recoverable headless (-nographic) — the
  # VGA console stays primary for the normal cutover.
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];
  # The installation image ships wpa_supplicant config-less; enable the
  # service so `wpa_cli` can drive it. Ethernet needs nothing.
  networking.wireless.enable = true;

  # Runbook tooling: sgdisk (partlabel renames), cryptsetup (open the
  # existing container — NEVER luksFormat, see MIGRATION.md), and an editor
  # for the unlucky-day on-site fix.
  environment.systemPackages = with pkgs; [
    git
    vim
    gptfdisk
    cryptsetup
  ];

  # The flake itself, frozen into the image.
  isoImage.contents = [
    {
      source = "${self}";
      target = "/nixos-config";
    }
  ];
}
