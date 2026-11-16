# ticoOS NIX

Configuração compartilhada do ticoOS: NixOS + Hyprland + Home Manager.

## Atualizar o ticoOS

Em um sistema instalado com a ISO recente:

```bash
sudo ticoOSupdate
```

Opções:

```bash
sudo ticoOSupdate --dry-run
sudo ticoOSupdate --rollback
```

O comando atualiza o input `ticoos` do flake local e reconstrói o sistema com
`nixos-rebuild switch`. A geração anterior continua disponível no boot.

## Estrutura

- `modules/`: configuração compartilhada do sistema.
- `hosts/ticoOS/`: exemplo de configuração local (hardware, boot, GPU, usuário).
- `iso/`: configuração da ISO e instalador Calamares.
- `vm.nix`: alvo de máquina virtual para testes.
- `home.nix`: configuração do usuário via Home Manager.

## Versão

BETA v0.1.1
