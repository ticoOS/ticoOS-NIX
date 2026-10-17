{
  inputs,
  pkgs,
  ... 
}: {
  programs.hyprland.enable = true;
  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];
  fonts.fontDir.enable = true;

  environment.systemPackages = [
    inputs.home-manager.packages.x86_64-linux.default
  ];

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

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
}
