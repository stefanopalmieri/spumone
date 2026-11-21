# Migration runbook — Debian → NixOS on `lenovo`

Status: rehearsal-complete. Every recipe in `just bootstrap` has a
verified NixOS mapping (see the git history of `nixos/rehearsal.nix` and
the linux-desktop skill's gotcha list); `nixos/lenovo.nix` +
`lenovo-hardware.nix` are the real machine, and this document is the
only thing between here and flipping it.

Golden rule: **nothing from the old world survives except (a) the data
you save in step 1 and (b) the LUKS container itself.** Everything else —
packages, configs, the root filesystem — is declared in this repo and
rebuilt from it. The old Debian rootfs is destroyed at step 4.5; after
that there is no Debian to roll back to, only a reinstall.

---

## 0. Preconditions (verify, don't assume)

- `git -C ~/.config/home-manager status` clean and pushed; this runbook
  and `nixos/lenovo*.nix` present.
- `lsblk` matches the table in `lenovo-hardware.nix`: sda1 vfat ~1G
  (→ `esp`), sda2 ext4 ~1G (retired), sda3 crypto_LUKS → lenovo-vg
  (root ~227G + swap 3.9G). **Abort and reconcile if it differs** — the
  hardware file is hand-written, not generated.
- A USB stick ≥ 2G (everything on it dies) and a working ethernet cord
  or the wifi passphrase. The install needs network for flake inputs and
  package substitutes.
- Half a day. The cutover itself is ~30 minutes; the rest is backups and
  verification.

## 1. Pre-flight EVA — on Debian, BEFORE touching anything

The repo's "Not automated (manual EVA on a true nuke)" list is the
checklist. Concretely:

```bash
# secrets: store is mirrored, but push now and verify the remote tip
cd ~/.local/share/password-store && git push && git ls-remote mini refs/heads/main

# gpg: refresh the armored export, then copy it OFF the machine
gpg --armor --export-secret-keys 3F580ECC39327F45 \
  > ~/.local/share/gpg-backup/stefano-secret-key.asc
# + USB: cp the .asc, ~/.ssh/, and a pass-store clone to external media
```

- `~/.ssh/` (the ed25519 key is passphraseless — its whole value is the
  file), browser bookmarks/profile if wanted, anything in $HOME not
  regenerable. `tar` it to the USB.
- `pass gpg/master-passphrase` — know it cold; the LUKS passphrase too
  (unchanged by this migration, but you'll type it at every boot).
- No other backups: emacs regenerates, the hm repo is the config, dot
  files are declared.

## 2. Build and burn the installer

```bash
cd ~/.config/home-manager
nix build .#nixosConfigurations.installer.config.system.build.isoImage --no-link --print-out-paths
# → /nix/store/...-nixos-minimal-...iso  (also under result/iso/)
```

Burn it (device, not partition — `lsblk` twice):

```bash
dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

The ISO carries this exact commit of the repo at `/nixos-config`
(read-only). If you committed anything after building, rebuild — the
image is a snapshot, not a link.

## 3. Boot it

`F12`/one-time boot menu → the USB (UEF). Land at the installer's
`nixos` auto-login. Plug ethernet, or for wifi:

```bash
wpass=$(printf 'passphrase'); printf 'network={ssid="SSID"\npsk="%s"}' "$wpass" > /tmp/wpa
wpa_supplicant -B -i wlan0 -c <(wpa_passphrase SSID 'the-passphrase')
# dhcpcd runs via the image's network config; check `ip a`
```

Sanity: `ls /nixos-config` (the repo), `nix --version`, `lsblk`.

## 4. The cutover

**4.1 — Partition labels only. NO re-partitioning, NO luksFormat.**
The existing LUKS container is reused (header + passphrase survive; the
old rootfs dies in 4.4 instead):

```bash
sgdisk -c 1:esp -c 3:cryptroot /dev/sda   # metadata-only rename
```

**4.2 — Open and mount:**

```bash
cryptsetup open /dev/disk/by-partlabel/cryptroot cryptroot   # existing passphrase
mkfs.ext4 -L root /dev/lenovo-vg/root        # WIPES the old Debian root
mkswap /dev/lenovo-vg/swap_1
mount /dev/lenovo-vg/root /mnt
mkdir /mnt/boot && mount /dev/disk/by-partlabel/esp /mnt/boot
```

**4.3 — Install:**

```bash
nixos-install --flake /nixos-config#lenovo --no-root-password
```

(No root password: sudo-only box, mirroring the README's Debian advice.)
This evaluates `nixos/lenovo.nix` + `lenovo-hardware.nix`, builds the
closure (network: hm/nixpkgs inputs + substitutes) and installs
systemd-boot into the ESP.

**4.4 — Reboot.** `reboot`, pull the stick. At the boot: systemd-boot →
initrd asks for the LUKS passphrase (the old one). First login
`stefano` / `rehearsal` — **run `passwd` immediately**; it's a
git-committed throwaway, not a credential.

If the boot fails: the stage-1 emergency shell is on the same console;
the usual suspects are a partlabel typo (`ls /dev/disk/by-partlabel`) or
a missing initrd module — both fixable by editing on a second
`nixos-install` run from the same USB.

## 5. First-boot verification — the `verify-i3` mirror

- [ ] login shell is zsh, starship spumone prompt renders
- [ ] `systemctl status lock-on-suspend` — loaded, enabled, inactive
- [ ] `pgrep -af polkit-gnome` — the agent lives, from the per-user bin
- [ ] `wpctl status` — Realtek/analog sink present (the VM's missing-sink
      anomaly was emulation; real HDA is the test that matters)
- [ ] `startx` → i3; `$mod+d` rofi, `$mod+b` chromium, `$mod+Return`
      vterm, volume keys, `Mod+Escape` locks
- [ ] `systemctl suspend` → resume shows the lock, password unlocks
- [ ] `home-manager generations` — generation 1, activation clean
- [ ] `nixos-rebuild list-generations` — the rollback point exists

## 6. Restore the secret store (data, not config)

```bash
git clone ssh://stefano@192.168.1.106/home/teaspoon/backups/passstore.git \
  ~/.local/share/password-store   # hm pins this path via PASSWORD_STORE_DIR
gpg --import ~/.local/share/gpg-backup/stefano-secret-key.asc     # + trust
gpg-agent: prime once interactively (pinentry-tty), cache is 24h
pass show gpg/master-passphrase   # roundtrip check, per the secrets skill
# bws token: pass show bws/access-token > ~/.config/bws/env && chmod 600 ...
# ssh key: untar from the USB, chmod 600, ssh-add once to confirm
```

## 7. Post-cutover deltas (known, deliberate)

- `vterm-deps` disappears as a recipe: add `gcc cmake libvterm` to
  system packages when a vterm rebuild is due. Re-verify the SSE story —
  the home.nix comment cites a Core 2 Duo T7250, this box reports
  Haswell; one of those is stale.
- `just` shrinks to `verify-i3` + `net`-style extras, then likely dies.
- The hm `nightly/*` flake-update flow becomes `nixos-rebuild test
  --flake` + `boot` — same gate, one level up.
- The Debian `/boot` partition (sda2) is retired; fold it in whenever.

## 8. Abort / rollback

Before step 4.4's reboot, nothing irreversible has happened except the
rootfs mkfs (4.2) — Debian is gone at that point, so decide BEFORE 4.2.
After cutover, the way back is the original Debian netinst + the README's
bootstrap, restoring from the step-1 USB. The rehearsal VM remains the
permanent sandbox for Nix-side experiments.
