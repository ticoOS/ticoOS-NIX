{ config, lib, pkgs, ... }:

let
  cfg = config.ticoOS;
in
{
  options.ticoOS = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "tico";
      description = "Primary desktop user.";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [ "intel" "amd" "nvidia" ];
      default = "intel";
      description = "Graphics driver profile.";
    };

    softwareRendering = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Force software rendering in Hyprland (VM/testing).";
    };
  };

  config = {
    networking.hostName = lib.mkDefault "ticoOS";
    system.stateVersion = "25.05";
    nixpkgs.config.allowUnfree = lib.mkDefault true;

    i18n.defaultLocale = lib.mkDefault "pt_BR.UTF-8";
    time.timeZone = lib.mkDefault "America/Sao_Paulo";
    console.keyMap = lib.mkDefault "br-abnt2";

    networking.networkmanager.enable = lib.mkDefault true;

    services.xserver.enable = true;
    services.xserver.xkb = lib.mkDefault {
      layout = "br";
      variant = "abnt2";
    };
    services.xserver.videoDrivers = lib.mkIf (cfg.gpu == "nvidia") [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia = lib.mkIf (cfg.gpu == "nvidia") {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    boot.kernelParams = lib.mkIf (cfg.gpu == "nvidia") [
      "nvidia_drm.modeset=1"
      "nvidia_drm.fbdev=1"
    ];
    boot.initrd.kernelModules = lib.mkIf (cfg.gpu == "nvidia") [
      "nvidia"
      "nvidia_drm"
    ];

    programs.hyprland.enable = true;

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    services.displayManager.defaultSession = "hyprland";

    security.polkit.enable = true;
    security.rtkit.enable = true;

    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    environment.pathsToLink = [
      "/share/applications"
      "/share/xdg-desktop-portal"
    ];

    fonts.fontDir.enable = true;

    environment.systemPackages = with pkgs; [
      kitty
      wofi
      git
      neovim
      polkit_gnome
    ];

    nix.settings = {
      auto-optimise-store = false;
      max-jobs = "auto";
      cores = 0;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}
