# Desktop system halves shared by EVERY host — rehearsal VM and real
# machines alike. This is the NixOS incarnation of the system-level halves
# that `just bootstrap` used to own on Debian; the per-user halves live in
# home.nix (hm attaches them via home-manager.users.<name>).
#
# Machine, and home.nix (hm attaches
# per-user halves via home-manager.users.<name>).
#
# Mapping, for the record:
#   just audio   -> services.pipewire + security.rtkit
#   just polkit  -> security.polkit (system) + the hm bin-wrap (user)
#   just startx  -> no DM (NixOS ships none unless asked) + the lock unit
{ pkgs, ... }:

{
  # RT scheduling for the audio graph — the module pair NixOS docs show
  # alongside services.pipewire; without it wireplumber spams RTKit
  # "ServiceUnknown" and the graph runs unprivileged-nice.
  security.rtkit.enable = true;

  # The i3 volume/mute keys (wpctl) talk to this. One declarative block
  # replaces the apt pipewire-audio metapackage + manual user-service enables.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Polkit's system half: the agent (home.nix bin-wrap) registers with
  # polkitd on the system bus; without it the agent has nothing to talk to.
  security.polkit.enable = true;

  # lock-before-suspend: the Debian unit (startx/lock-on-suspend.service) as
  # a first-class NixOS unit — same Before/RequiredBy sleep.target
  # choreography, forking i3lock in Spacemacs bg1. Deltas from the template:
  # User is declarative (no __USER__ sed) and i3lock resolves from the
  # closure — there is no /usr/bin on NixOS.
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
}
