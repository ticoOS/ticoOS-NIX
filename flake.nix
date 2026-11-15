{
  description = "Configuracao centralizada do ticoOS NIX";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      lib = nixpkgs.lib;

      mkSystem = { modules ? [ ] }: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ self.nixosModules.default ] ++ modules;
      };

      dev = mkSystem { modules = [ ./hosts/ticoOS/local.nix ]; };
      vm = mkSystem { modules = [ ./vm.nix ]; };

      iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./iso/configuration.nix
          ./system.nix
        ];
      };

      hasIso = builtins.pathExists ./iso/configuration.nix;
      isoPackage = iso.config.system.build.isoImage;
      vmPackage = vm.config.system.build.vm;
    in
    {
      nixosModules.default = ./modules/default.nix;

      lib.mkSystem = mkSystem;

      nixosConfigurations = {
        ticoOS = dev;
        ticoOS-vm = vm;
      } // lib.optionalAttrs hasIso {
        ticoOS-iso = iso;
      };

      packages.x86_64-linux = {
        vm = vmPackage;
      } // lib.optionalAttrs hasIso {
        default = isoPackage;
        iso = isoPackage;
      };

      homeConfigurations.tico = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home.nix
          inputs.nixvim.homeManagerModules.nixvim
        ];
      };
    };
}
