{ lib, ... }: {
  users.users.tico.initialPassword = lib.mkForce "vm";

  services.displayManager.autoLogin = {
    enable = true;
    user = lib.mkForce "tico";
  };

  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  home-manager.users.tico.wayland.windowManager.hyprland.settings.env = lib.mkForce [
    "WLR_NO_HARDWARE_CURSORS,1"
    "WLR_RENDERER_ALLOW_SOFTWARE,1"
    "LIBGL_ALWAYS_SOFTWARE,1"
  ];

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
