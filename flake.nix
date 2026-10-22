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
      homeManagerIntegration = { config, ... }: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.${config.ticoOS.username} = {
          imports = [
            ./home.nix
            inputs.nixvim.homeManagerModules.nixvim
          ];
        };
      };
    in
    {
      overlays.default = final: prev: {
        calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            cp ${./installer/calamares/main.py} modules/nixos/main.py
            sed -i '/^  - packagechooser$/d; /^  - notesqml@unfree$/d' config/settings.conf
            sed -i '/^- exec:/,/^- show:/{/^  - users$/d}' config/settings.conf
          '';
        });

        calamares-nixos = prev.calamares.override {
          extraWrapperArgs = [
            "--prefix XDG_DATA_DIRS : ${final.calamares-nixos-extensions}/share"
            "--prefix XDG_CONFIG_DIRS : ${final.calamares-nixos-extensions}/etc"
            "--add-flag --xdg-config"
          ];
        };
      };

      nixosConfigurations.ticoOS = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          homeManagerIntegration
        ];
      };

      nixosConfigurations.ticoOS-iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ self.overlays.default ]; }
          ./iso/default.nix
          home-manager.nixosModules.home-manager
          homeManagerIntegration
        ];
      };

      nixosConfigurations.ticoOS-vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./modules/common.nix
          ./calamares-user.nix
          ./vm.nix
          home-manager.nixosModules.home-manager
          homeManagerIntegration
        ];
      };

      homeConfigurations.tico = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          username = "tico";
        };
        modules = [
          ./home.nix
          inputs.nixvim.homeManagerModules.nixvim
        ];
      };
    };
}
