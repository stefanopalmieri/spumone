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
      # output (e.g. `homeConfigurations.bob = mkHome "bob";`) and activate
      # with `home-manager switch --flake .#bob`. Named after the crew member
      # rather than read from the environment because pure flake eval can't
      # see $USER (and we don't want to require --impure).
      mkHome = username:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = { inherit username; };
        };
    in {
      homeConfigurations.stefano = mkHome "stefano";
    };
}
