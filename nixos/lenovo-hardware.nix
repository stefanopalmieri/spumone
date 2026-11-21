# Hardware layer for `lenovo` — hand-written, NOT nixos-generate-config
# output: the cutover (MIGRATION.md) keeps the Debian-era block devices, so
# everything here is known BEFORE the first installer command runs. Devices
# are addressed by GPT partlabel / mapper / LV name — never UUIDs — so this
# file never needs touching during the cutover.
#
# Layout carried over from Debian (verify with `lsblk` in step 2 of
# MIGRATION.md; abort if it doesn't match):
#   sda1  vfat  partlabel "esp"        -> /boot    (systemd-boot)
#   sda2  ext4  (Debian /boot)         -> retired, untouched
#   sda3  LUKS  partlabel "cryptroot"  -> PV lenovo-vg
#     ├─ lenovo-vg/root   ext4 -> /       (recreated at cutover)
#     └─ lenovo-vg/swap_1 swap            (re-mkswap'd at cutover)
# The LUKS container itself is KEPT — same header, same passphrase; only
# the filesystems inside are recreated.
{ modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Haswell-era laptop: SATA AHCI disk, xhci/eichi USB. dm_* come via the
  # luks/lvm stage-1 hooks below; add what a rescue boot misses, never guess
  # less: the stage-1 emergency shell is the fallback.
  boot.initrd.availableKernelModules = [
    "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" "sr_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # The LUKS container is reused, not recreated: name matches the mapper
  # opened in MIGRATION.md step 4 (`cryptsetup open ... cryptroot`).
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-partlabel/cryptroot";
  };

  fileSystems."/" = {
    device = "/dev/lenovo-vg/root";
    fsType = "ext4";
  };

  # ESP: systemd-boot reads only FAT, so the kernel/initrd live here.
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/esp";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ { device = "/dev/lenovo-vg/swap_1"; } ];
}
