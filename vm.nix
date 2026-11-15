{ config, lib, ... }: {
  ticoOS.gpu = lib.mkForce "vm";

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];

  users.users.${config.ticoOS.username}.initialPassword = lib.mkForce "vm";

  services.displayManager.autoLogin = {
    enable = true;
    user = lib.mkForce config.ticoOS.username;
  };

  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 4;
      diskSize = 8192;
      graphics = true;
      qemu.options = [
        "-display gtk,grab-on-hover=on"
      ];
    };
  };
}
