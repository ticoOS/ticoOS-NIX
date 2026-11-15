{ lib, ... }: {
  ticoOS.gpu = lib.mkDefault "auto";
  hardware.graphics.enable = true;
}
