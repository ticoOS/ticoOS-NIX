{
  pkgs,
  inputs,
  lib,
  osConfig ? null,
  username ? "tico",
  ...
}:

let
  gpu = if osConfig != null then (osConfig.ticoOS.gpu or "auto") else "auto";
  isVm = gpu == "vm";
  ticoosVersion = if osConfig != null then (osConfig.ticoOS.version or "0.1.0") else "0.1.0";
  ticoosHelp = pkgs.writeShellApplication {
    name = "ticoos-help";
    runtimeInputs = [ pkgs.zenity ];
    text = ''
    zenity --info --title="Comandos básicos do ticoOS" --width=620 --height=480 --ok-label="Fechar"  --text='<b>SUPER + Q</b> _ Terminal (kitty)
  <b>SUPER + SPACE</b> _ Launcher (rofi)
  <b>SUPER + H</b> _ Comandos básicos
  <b>SUPER + C</b> _ Fechar janela
  <b>SUPER + E</b> _ Yazi (Gerenciador de arquivos)
  <b>SUPER + M</b> _ Sair do hyprland (TTY)
  <b>SUPER + 1..9</b> _ Trocar de workspaces 
  <b>SUPER + SHIFT + 1..9</b> _ Mover janela workspace
  <b>PRINT</b> _ Screenshot da tela
  <b>PRINT + SHIFT</b> _ Screenshot em area
  <small>Volume e brilho: teclas de mídia</small>'
    '';
  };

  hyprlandEnv =
    if isVm then [
      "WLR_NO_HARDWARE_CURSORS,1"
      "WLR_RENDERER_ALLOW_SOFTWARE,1"
      "LIBGL_ALWAYS_SOFTWARE,1"
    ]
    else if gpu == "nvidia" then [
      "LIBVA_DRIVER_NAME,nvidia"
      "GBM_BACKEND,nvidia-drm"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      "WLR_NO_HARDWARE_CURSORS,1"
    ]
    else [
      "WLR_NO_HARDWARE_CURSORS,1"
    ];
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    btop
    fastfetch
    figlet
    wl-clipboard
    nerd-fonts.jetbrains-mono
    hyprshot
    kitty
    slurp
    pavucontrol
    blueman
    dunst
    libnotify
    brightnessctl
    awww
    git
    yazi
    zenity
    ticoosHelp
    opencode

    (stdenv.mkDerivation {
      pname = "vcr-osd-mono";
      version = "1.001";
      src = fetchFromGitHub {
        owner = "jabes";
        repo = "terrace";
        rev = "master";
        sha256 = "sha256-hiJcbShJ/ob2Q2Iwe0QguNGKRZ3xwSq0ChUNukYQt+4=";
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/share/fonts/truetype
        cp $src/Terrace/resources/fonts/VCR-OSD-Mono.ttf $out/share/fonts/truetype/VCR_OSD_MONO.ttf
      '';
    })

    (writeShellApplication {
      name = "ticoos-welcome";
      runtimeInputs = [ zenity xdg-utils coreutils ];
      text = ''
        marker="$HOME/.config/ticoos/welcome-shown"
        if [ -e "$marker" ]; then
          exit 0
        fi

        mkdir -p "$(dirname "$marker")"

       while true; do  
        choice="$(zenity --list \
          --title="Bem-vindo ao ticoOS" \
          --text='<span size="x-large" weight="bold">ticoOS BETA v${ticoosVersion}</span>

Bem-vindo ao ticoOS! Escolha uma opção:' \
          --column="Ação" \
          --width=560 --height=380 \
          --ok-label="Continuar" \
          "Comandos básicos" "Abrir o site" "Entrar no Discord" "Fechar" 2>/dev/null || true)"

        case "$choice" in
          "Comandos básicos") ${ticoosHelp}/bin/ticoos-help ;;
          "Abrir o site") xdg-open "https://ticoos.github.io" >/dev/null 2>&1 || true ;;
          "Entrar no Discord") xdg-open "https://discord.gg/RcHbENp8wj" >/dev/null 2>&1 || true ;;
          "Fechar"|"") break ;;
         esac
        done

        touch "$marker"
      '';
    })
  ];

  fonts.fontconfig.enable = true;

  programs.firefox.enable = true;

  programs.git = {
    enable = true;
    userName = "Seu Nome Aqui";
    userEmail = "seu-email@exemplo.com";
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "VCR OSD Mono";
      size = 13;
    };
    settings = {
      background_opacity = "0.9";
      disable_ligatures = "never";
    };
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      clear
      echo "___________________________________________________"
      figlet -f slant "ticoOS NIX"
      echo "TICO.CO todos direitos reservados ©2026"
      echo "___________________________________________________"
      echo "BETA v${ticoosVersion}"
      echo ""
      1155() {
        figlet -f slant "seco seco filho"
      }
    '';
  };

  programs.rofi = {
    enable = true;
    font = "JetBrainsMono Nerd Font 12";
    extraConfig = {
      modi = "drun,run";
      show-icons = true;
      drun-display-format = "{name}";
      disable-history = false;
      sidebar-mode = false;
    };
  };

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [ "pulseaudio" "battery" "clock" ];
        "clock" = { format = "{:%H:%M - %d/%m}"; };
        "battery" = { format = "{capacity}% 🔋"; };
        "pulseaudio" = { format = "{volume}% 🔊"; };
      };
    };
    style = ''
      window#waybar {
        background-color: rgba(20, 20, 30, 0.9);
        border-bottom: 2px solid #3b4252;
        color: #ffffff;
        font-family: "JetBrainsMono Nerd Font", sans-serif;
        font-size: 13px;
      }
      #clock, #battery, #pulseaudio { padding: 0 10px; }
    '';
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      smartindent = true;
      clipboard = "unnamedplus";
    };

    clipboard = {
      providers.wl-copy.enable = true;
    };

    colorschemes.catppuccin = {
      enable = true;
      settings.flavour = "mocha";
    };

    plugins = {
      oil.enable = true;
      telescope.enable = true;
      treesitter.enable = true;
      gitsigns.enable = true;
      lualine.enable = true;

      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true;
          lua_ls.enable = true;
          pyright.enable = true;
        };
      };

      cmp = {
        enable = true;
        settings.sources = [
          { name = "nvim_lsp"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>pv";
        action = "<cmd>Oil<CR>";
        options = { desc = "Abrir gerenciador de arquivos Oil"; };
      }
    ];
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };
    };
  };

  services.ssh-agent.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      autogenerated = 0;
      "$mainMod" = "SUPER";
      "$terminal" = "kitty";

      env = hyprlandEnv;

      monitor = ",preferred,auto,1";

      input = {
        kb_layout = "br";
        kb_variant = "abnt2";
        kb_model = "abnt2";
      };

      exec-once = [
        "waybar"
        "dunst"
        "awww-daemon"
        "test -f ~/Pictures/wallpaper.png && awww img ~/Pictures/wallpaper.png"
        "ticoos-welcome"
      ];

      bind = [
        "$mainMod, Q, exec, $terminal"
        "$mainMod, SPACE, exec, rofi -show drun"
        "$mainMod, C, exec, hyprctl dispatch killactive"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, $terminal -e yazi"
        "$mainMod, H, exec, ticoos-help"

        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86MonBrightnessUp, exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"

        ", PRINT, exec, hyprshot -m output -o ~/Pictures"
        "$mainMod, PRINT, exec, hyprshot -m region -o ~/Pictures"

        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"

        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
      ];
    };
  };
}
