{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./common.nix
    ./update.nix
    ./cachix.nix
    ../system.nix
    ../splash.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager.extraSpecialArgs = {
    inherit inputs;
    username = config.ticoOS.username;
    fullname = config.ticoOS.fullname;
  };
  home-manager.users.${config.ticoOS.username}.imports = [
    ../home.nix
    inputs.nixvim.homeManagerModules.nixvim
  ];
}
