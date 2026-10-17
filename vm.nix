{ ... }: {
  ticoOS.isVm = true;
  ticoOS.enableNvidia = false;

  users.users.tico.initialPassword = "vm";

  services.displayManager.autoLogin = {
    enable = true;
    user = "tico";
  };

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
