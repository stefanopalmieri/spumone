{
  description = "Stefano's Home Manager configuration (Debian + i3 + Emacs/Spacemacs)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Build a Home Manager configuration for a given username. The username
      # is threaded into home.nix via extraSpecialArgs so the module itself
      # stays user-agnostic. To fly under a different callsign, add another
      # output (e.g. `homeConfigurations.bob = mkHome "bob" {};`) and activate
      # with `home-manager switch --flake .#bob`. Named after the crew member
      # rather than read from the environment because pure flake eval can't
      # see $USER (and we don't want to require --impure).
      #
      # The second argument, `host`, is an attrset of host-specific traits
      # (e.g. `{ lowres = true; }`) threaded into home.nix as `extraSpecialArgs.host`.
      # Each trait maps to a tweak snippet — currently `lowres` appends
      # i3/lowres.conf (a floating-window size cap + centered dialogs for
      # sub-HD panels). We can't auto-detect the host during pure flake eval,
      # so each host gets its own named output instead. An attrset (rather
      # than a boolean) ages better: a future `hidpi`, `mobile`, etc. trait
      # is just another key + another snippet, with no new output plumbing.
      mkHome = username: host:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = { inherit username host; };
        };
    in {
      homeConfigurations.stefano     = mkHome "stefano" {};
      # ThinkPad X61 (1024x768): opts into the `lowres` trait, which appends
      # i3/lowres.conf (floating-window size cap + centered dialogs) so
      # file chooser / print dialogs fit the panel.
      homeConfigurations.stefano-x61 = mkHome "stefano" { lowres = true; };
      # Lenovo (1366x768): same sub-HD panel *height* as the X61, so the
      # 1000x700 cap from `lowres` fits with room to spare (768 - 28 px
      # i3bar = 740 usable). Reuse the trait rather than adding a
      # lowres-1366 snippet for a width we don't need to shrink.
      homeConfigurations.stefano-lenovo = mkHome "stefano" { lowres = true; };

      # NixOS rehearsal VM (see nixos/rehearsal.nix): the full-Nix endgame
      # rehearsed in qemu, one milestone per commit. Same flake inputs, so
      # the VM sees exactly the nixpkgs/home-manager pins the hosts see.
      nixosConfigurations.rehearsal = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./nixos/rehearsal.nix ];
      };
    };
}
