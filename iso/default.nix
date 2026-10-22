{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares.nix"
    ../modules/common.nix
  ];

  ticoOS.username = "tico";

  users.users.tico = {
    isNormalUser = true;
    description = "tico";
    extraGroups = [ "wheel" "networkmanager" "video" "render" "audio" ];
    initialPassword = "123";
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "tico";
  };
  services.getty.autologinUser = lib.mkForce "tico";

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  environment.etc."ticoos-installer/flake".source = ../.;

  isoImage.edition = "ticoOS-BETA";
}
