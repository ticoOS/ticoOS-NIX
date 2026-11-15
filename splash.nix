{ pkgs, ... }:
{
  console.font = "ter-v16n";
  console.packages = [ pkgs.terminus_font ];

  systemd.services.ticoos-banner = {
    description = "ticoOS ASCII boot banner";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" "systemd-modules-load.service" ];
    before = [ "getty@tty1.service" "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = false;
      TTYVHangup = false;
      TTYVTDisallocate = false;
    };
    script = ''
      cols="$(stty -F /dev/tty1 size 2>/dev/null | cut -d' ' -f2 || true)"
      [ -z "$cols" ] && cols=240
      ${pkgs.figlet}/bin/figlet -w "$cols" -c -f slant "ticoOS NIX"
      line="TICO.CO todos os direitos reservados ©2026"
      pad=$(( (cols - ''${#line}) / 2 ))
      printf '%*s%s\n' "$pad" "" "$line"
      echo ""
    '';
  };
}
