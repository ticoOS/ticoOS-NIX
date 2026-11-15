{ config, lib, pkgs, ... }:
{
  options.ticoOS = {
    gpu = lib.mkOption {
      type = lib.types.enum [ "auto" "nvidia" "nouveau" "amd" "intel" "vm" ];
      default = "auto";
      description = "Perfil de driver de video usado pelo ticoOS.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = "tico";
      description = "Usuario principal do ticoOS.";
    };

    fullname = lib.mkOption {
      type = lib.types.str;
      default = "tico";
      description = "Nome completo do usuario principal.";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.0.2";
      description = "Versao do ticoOS.";
    };

    autoUpdate.enable = lib.mkEnableOption "atualizacoes automaticas do ticoOS";
  };

  config = {
    system.stateVersion = "25.05";

    programs.hyprland.enable = true;
    services.desktopManager.gnome.enable = false;
    services.displayManager.defaultSession = "hyprland";

    security.polkit.enable = true;
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

    environment.systemPackages = with pkgs; [
      kitty
      wofi
      git
      neovim
      polkit_gnome
    ];

    networking.networkmanager.enable = true;
    i18n.defaultLocale = "pt_BR.UTF-8";
    console.keyMap = "br-abnt2";
    services.xserver.xkb.layout = "br";

    users.users.${config.ticoOS.username} = {
      isNormalUser = true;
      description = config.ticoOS.fullname;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    };

    environment.etc."ticoos/version".text = config.ticoOS.version;

    nixpkgs.config.allowUnfree = lib.mkDefault (config.ticoOS.gpu == "nvidia");
  };
}
