{ pkgs, modulesPath, ... }: {
  imports = [
    # Base oficial gráfica com o instalador Calamares pré-configurado
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares.nix"
  ];

  networking.hostName = "ticoOS";
  system.stateVersion = "25.05";
  nixpkgs.config.allowUnfree = true;

  # 1. COMPATIBILIDADE DE HARDWARE E DISCOS VIRTUAIS
  services.qemuGuest.enable = true;
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];

  # 2. ENTRA DIRETO NO HYPRLAND NA ISO LIVE
  programs.hyprland.enable = true;                      
  services.desktopManager.gnome.enable = pkgs.lib.mkForce false;

  # O Calamares Live exige logar como "nixos" para o script Python funcionar sem erros
  services.displayManager.autoLogin = { enable = true; user = "nixos"; };
  services.displayManager.defaultSession = "hyprland";

  # Criando o usuário "nixos" para a ISO rodar o instalador sem travar
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "disk" "storage" "kvm" ];
  };

  # Criando o seu usuário administrador "tico" na ISO
  users.users.tico = {
    isNormalUser = true;
    extraGroups = [ "wheel" "disk" "storage" "kvm" ];
    initialPassword = "123";
  };

  # Ativa o Polkit GNOME para dar suporte a autenticações gráficas no Hyprland
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

  # AUTOSTART DO CALAMARES CORRIGIDO
  environment.etc."xdg/autostart/calamares.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Instalar ticoOS
    Exec=calamares
    Icon=calamares
    Categories=System;Installer;
  '';

  environment.systemPackages = with pkgs; [
    kitty wofi git neovim polkit_gnome
  ];

  networking.networkmanager.enable = true;
  i18n.defaultLocale = "pt_BR.UTF-8";
  console.keyMap = "br-abnt2";
  isoImage.edition = "ticoOS-BETA";

  # 3. SEGREDO DA DISTRO: O que vai para o HD do usuário final (Puro Hyprland)
  installer.cloneConfig = false;
  installer.cloneConfigExtra = ''
    { pkgs, ... }: {
      imports = [ ./hardware-configuration.nix ];
      
      boot.loader.systemd-boot.enable = true;
      boot.loader.systemd-boot.installAsRemovable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      
      networking.hostName = "ticoOS-distro";
      networking.networkmanager.enable = true;
      
      programs.hyprland.enable = true;
      environment.systemPackages = with pkgs; [ kitty wofi git neovim ];
      
      services.desktopManager.gnome.enable = false;
      services.getty.autologinUser = "tico";

      # Isso garante que o usuário "tico" seja criado no computador de quem instalar a ISO
      users.users.tico = {
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
        initialPassword = "123";
      };
      
      nixpkgs.config.allowUnfree = true;
      i18n.defaultLocale = "pt_BR.UTF-8";
      console.keyMap = "br-abnt2";
      services.xserver.xkb.layout = "br";
      
      system.stateVersion = "25.05";
    }
  '';
}


