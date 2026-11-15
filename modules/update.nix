{ config, lib, pkgs, ... }:
let
  ticoOSupdate = pkgs.writeShellApplication {
    name = "ticoOSupdate";
    runtimeInputs = with pkgs; [ nix git coreutils gnugrep gnused ];
    text = ''
      NIXOS_REBUILD="${config.system.build.nixos-rebuild}/bin/nixos-rebuild"

      if [ "$(id -u)" -ne 0 ]; then
        echo "Use: sudo ticoOSupdate" >&2
        exit 1
      fi

      dry_run=false
      assume_yes=false
      for arg in "$@"; do
        case "$arg" in
          --dry-run) dry_run=true ;;
          --yes|-y) assume_yes=true ;;
          --rollback)
            exec "$NIXOS_REBUILD" switch --rollback
            ;;
          --version)
            echo "ticoOS: $(cat /etc/ticoos/version 2>/dev/null || echo desconhecida)"
            nixos-version
            exit 0
            ;;
          *)
            echo "Opcao desconhecida: $arg" >&2
            exit 1
            ;;
        esac
      done

      cd /etc/nixos
      if ! grep -q 'ticoos' flake.nix; then
        echo "Este sistema nao esta configurado para atualizacoes." >&2
        exit 1
      fi

      echo "Versao atual: $(cat /etc/ticoos/version 2>/dev/null || echo desconhecida)"

      if [ "$assume_yes" = false ]; then
        printf "Atualizar o ticoOS agora? [s/N] "
        read -r reply
        case "$reply" in
          s|S|y|Y) ;;
          *) echo "Cancelado."; exit 0 ;;
        esac
      fi

      nix --extra-experimental-features 'nix-command flakes' flake update ticoos

      if [ "$dry_run" = true ]; then
        "$NIXOS_REBUILD" build --flake .#ticoOS
        echo "Dry-run concluido; nada foi ativado."
        exit 0
      fi

      "$NIXOS_REBUILD" switch --flake .#ticoOS
      echo "Atualizacao concluida. Nova versao: $(cat /etc/ticoos/version 2>/dev/null || echo desconhecida)"
    '';
  };
in
{
  environment.systemPackages = [ ticoOSupdate ];

  systemd.services.ticoos-update = lib.mkIf config.ticoOS.autoUpdate.enable {
    description = "ticoOS automatic update";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ticoOSupdate}/bin/ticoOSupdate --yes";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.timers.ticoos-update = lib.mkIf config.ticoOS.autoUpdate.enable {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      RandomizedDelaySec = "1h";
      Persistent = true;
      Unit = "ticoos-update.service";
    };
  };
}
