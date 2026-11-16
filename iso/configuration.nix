{ config, lib, pkgs, inputs, modulesPath, ... }:
let
  liveHyprlandConfig = pkgs.runCommand "ticoos-live-hyprland.lua" { } ''
    cat ${pkgs.hyprland}/share/hypr/hyprland.lua > $out
    cat >> $out <<'EOF'

hl.on("hyprland.start", function()
  hl.exec_cmd("sudo -E calamares")
end)
EOF
  '';

  keepInputs = pkgs.runCommand "ticoos-flake-inputs" { } ''
    mkdir -p $out
    printf '%s\n' \
      ${inputs.nixpkgs.outPath} \
      ${inputs.home-manager.outPath} \
      ${inputs.nixvim.outPath} \
      ${inputs.nixvim.inputs.flake-parts.outPath} \
      ${inputs.nixvim.inputs.systems.outPath} \
      > $out/paths
  '';
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares.nix"
  ];

  nixpkgs.overlays = [
    (final: prev: {
      calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          cp ${./calamares-main.py} modules/nixos/main.py
          sed -i '/^  - packagechooser$/d' config/settings.conf
          sed -i 's/requiredStorage: .*/requiredStorage: 20/' config/modules/welcome.conf
          sed -i 's/requiredRam: .*/requiredRam: 2.0/' config/modules/welcome.conf
        '';
      });
    })
  ];

  networking.hostName = "ticoOS";
  system.stateVersion = "25.05";
  nixpkgs.config.allowUnfree = true;

  services.qemuGuest.enable = true;
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "ahci" "sd_mod" ];

  hardware.graphics.enable = true;

  programs.hyprland.enable = true;
  services.desktopManager.gnome.enable = lib.mkForce false;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.desktopManager.xfce.enableScreensaver = false;
  services.xserver.videoDrivers = [ "modesetting" "vesa" ];

  services.displayManager.sddm.wayland.enable = lib.mkForce false;
  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };
  services.displayManager.defaultSession = "hyprland";

  security.pam.services.login.allowNullPassword = true;
  security.pam.services.sddm.allowNullPassword = true;

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "disk" "storage" "kvm" ];
  };

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

  environment.etc."xdg/autostart/calamares.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Instalar ticoOS
    Exec=sudo -E calamares
    Icon=calamares
    Categories=System;Installer;
  '';

  environment.etc."xdg/autostart/ticoos-noblank.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Desativar descanso de tela
    Exec=sh -c 'xset s off -dpms; xset s noblank'
    X-GNOME-Autostart-enabled=true
  '';

  environment.etc."ticoos/hyprland.lua".source = liveHyprlandConfig;

  systemd.tmpfiles.rules = [
    "d /home/nixos/.config 0755 nixos users -"
    "d /home/nixos/.config/hypr 0755 nixos users -"
    "L+ /home/nixos/.config/hypr/hyprland.lua - - - - /etc/ticoos/hyprland.lua"
  ];

  environment.sessionVariables = {
    LIBGL_ALWAYS_SOFTWARE = "1";
    MESA_LOADER_DRIVER_OVERRIDE = "llvmpipe";
    GALLIUM_DRIVER = "llvmpipe";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  environment.systemPackages = with pkgs; [
    kitty
    wofi
    git
    neovim
    polkit_gnome
    pciutils
    xset
  ];

  networking.networkmanager.enable = true;
  i18n.defaultLocale = "pt_BR.UTF-8";
  console.keyMap = "br-abnt2";
  isoImage.edition = "ticoOS-BETA";

  installer.cloneConfig = false;

  system.extraDependencies = [ keepInputs ];
}
