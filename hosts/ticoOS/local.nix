{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./hostname.nix
    ./gpu.nix
  ];

  ticoOS.username = lib.strings.trim (builtins.readFile ./username);
  ticoOS.fullname = lib.strings.trim (builtins.readFile ./fullname);
  ticoOS.autoUpdate.enable = false;
}
