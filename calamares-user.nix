{ ... }:
{
  ticoOS.username = "tico";

  users.users.tico = {
    isNormalUser = true;
    description = "tico";
    extraGroups = [ "wheel" "networkmanager" "video" "render" "audio" ];
    initialPassword = "123";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ticoOS";
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "pt_BR.UTF-8";
  console.keyMap = "br-abnt2";
  services.xserver.xkb = {
    layout = "br";
    variant = "abnt2";
  };
}
