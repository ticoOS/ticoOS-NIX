{ config, lib, ... }:
let
  cfg = config.ticoOS.cache;
in
{
  options.ticoOS.cache = {
    enable = lib.mkEnableOption "cache binario do ticoOS";
    name = lib.mkOption {
      type = lib.types.str;
      default = "ticoos";
      description = "Nome do cache no Cachix.";
    };
    publicKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Chave publica do cache Cachix.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings.substituters = lib.mkAfter [ "https://${cfg.name}.cachix.org" ];
    nix.settings.trusted-public-keys = lib.mkAfter (
      lib.optional (cfg.publicKey != "") cfg.publicKey
    );
  };
}
