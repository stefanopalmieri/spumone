{
  description = "Stefano's Home Manager configuration (Lubuntu + i3 + Emacs/Spacemacs)";

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
      # output (e.g. `homeConfigurations.bob = mkHome "bob" false;`) and
      # activate with `home-manager switch --flake .#bob`. Named after the
      # crew member rather than read from the environment because pure flake
      # eval can't see $USER (and we don't want to require --impure).
      #
      # The second argument, `lowres`, opts into machine-specific tweaks for
      # low-resolution panels (e.g. the ThinkPad X61's 1024x768 LVDS) — see
      # i3/lowres-x61.conf. We can't auto-detect the host during pure flake
      # eval, so each host gets its own named output instead.
      mkHome = username: lowres:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = { inherit username lowres; };
        };
    in {
      homeConfigurations.stefano     = mkHome "stefano" false;
      # ThinkPad X61 (1024x768): enables i3/lowres-x61.conf (floating-window
      # size cap + centered dialogs) so file chooser / print dialogs fit.
      homeConfigurations.stefano-x61 = mkHome "stefano" true;
    };
}
