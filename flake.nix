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
      homeManagerIntegration = {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.tico = {
          imports = [
            ./home.nix
            inputs.nixvim.homeManagerModules.nixvim
          ];
        };
      };
    in
    {

      nixosConfigurations.ticoOS = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./system.nix
          home-manager.nixosModules.home-manager
          homeManagerIntegration
        ];
      };

      nixosConfigurations.ticoOS-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./vm.nix
          ./system.nix
          home-manager.nixosModules.home-manager
          homeManagerIntegration
        ];
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
