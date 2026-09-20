{ config, lib, pkgs, ... }:

let
  cfg = config.ticoOS;
in
{
  options.ticoOS = {
    enableNvidia = lib.mkEnableOption "NVIDIA GPU support";
    isVm = lib.mkEnableOption "virtual machine mode";
  };

  config = lib.mkMerge [
    {
      ticoOS.enableNvidia = lib.mkDefault true;
      ticoOS.isVm = lib.mkDefault false;
    }

    (lib.mkIf (!cfg.isVm) {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
    })

    (lib.mkIf cfg.isVm {
      boot.loader.grub.enable = false;
      boot.initrd.systemd.enable = true;
    })

    {
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      boot.kernelPackages = pkgs.linuxPackages_latest;

      networking.hostName = "ticoOS";
      networking.networkmanager.enable = true;

      services.displayManager.defaultSession = "hyprland";

      time.timeZone = "America/Sao_Paulo";

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      i18n.defaultLocale = "pt_BR.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "pt_BR.UTF-8";
        LC_IDENTIFICATION = "pt_BR.UTF-8";
        LC_MEASUREMENT = "pt_BR.UTF-8";
        LC_MONETARY = "pt_BR.UTF-8";
        LC_NAME = "pt_BR.UTF-8";
        LC_NUMERIC = "pt_BR.UTF-8";
        LC_PAPER = "pt_BR.UTF-8";
        LC_TELEPHONE = "pt_BR.UTF-8";
        LC_TIME = "pt_BR.UTF-8";
      };

      services.xserver.xkb = {
        layout = "br";
        variant = "";
      };

      console.keyMap = "br-abnt2";

      users.users."tico" = {
        isNormalUser = true;
        description = "tico";
        extraGroups = [ "networkmanager" "wheel" ];
        packages = with pkgs; [];
      };

      nixpkgs.config.allowUnfree = true;
      system.stateVersion = "26.05";
    }

    (lib.mkIf cfg.enableNvidia {
      boot.kernelParams = [ "nvidia_drm.modeset=1" "nvidia_drm.fbdev=1" ];
      boot.initrd.kernelModules = [ "nvidia" "nvidia_drm" ];
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = false;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };

      environment.sessionVariables = {
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        WLR_NO_HARDWARE_CURSORS = "1";
      };
    })
  ];
}
