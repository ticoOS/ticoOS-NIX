{ lib, ... }:
{
  ticoOS.softwareRendering = true;
  ticoOS.gpu = "intel";

  users.users.tico.initialPassword = lib.mkForce "vm";

  services.displayManager.autoLogin = {
    enable = true;
    user = lib.mkForce "tico";
  };
  services.getty.autologinUser = lib.mkForce "tico";

  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 8192;
      graphics = true;
      qemu.options = [
        "-display gtk,grab-on-hover=on"
      ];
    };
  };
}
