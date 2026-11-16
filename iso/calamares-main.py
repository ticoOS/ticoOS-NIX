#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import gettext
import json
import os
import shutil
import subprocess
import traceback

import libcalamares

_ = gettext.translation(
    "calamares-python",
    localedir=libcalamares.utils.gettext_path(),
    languages=libcalamares.utils.gettext_languages(),
    fallback=True,
).gettext


def pretty_name():
    return _("Installing ticoOS.")


status = pretty_name()


def pretty_status_message():
    return status


def _elevated(command):
    if os.geteuid() == 0:
        return command
    return ["pkexec"] + command


def _proxy_environment():
    values = []
    for name in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY"):
        value = os.environ.get(name)
        if value:
            values.append("{}={}".format(name, value))
    if values:
        values.insert(0, "env")
    return values


class NixProgress:
    def __init__(self):
        self._activities = {}
        self._progress = {}
        self._copy_bytes = {}
        self._done = 0
        self._expected = 0
        self._floor = 0.0
        self._floor_done = 0
        self.fraction = 0.0
        self.messages = []

    def handle(self, line):
        line = line.strip()
        if not line:
            return True
        if not line.startswith("@nix "):
            return False
        try:
            message = json.loads(line[5:])
        except (ValueError, json.JSONDecodeError):
            return False
        try:
            action = message.get("action")
            if action == "start":
                self._activities[message["id"]] = message.get("type", 0)
                text = message.get("text", "")
                if text and message.get("level", 5) <= 3:
                    self.messages.append(text)
            elif action == "stop":
                self._activities.pop(message.get("id"), None)
                self._copy_bytes.pop(message.get("id"), None)
            elif action == "result":
                self._on_result(message)
            elif action == "msg":
                if message.get("level", 0) <= 1 and message.get("msg"):
                    self.messages.append(message["msg"])
            self._update()
        except Exception:
            pass
        return True

    def _on_result(self, message):
        activity_id = message.get("id")
        result_type = message.get("type", 0)
        fields = message.get("fields", [])
        activity_type = self._activities.get(activity_id, 0)

        if activity_type == 100 and len(fields) >= 2:
            self._copy_bytes[activity_id] = (fields[0], max(fields[1], 1))
            return

        if result_type != 105 or len(fields) < 2:
            return
        if activity_type not in (103, 104):
            return

        self._progress[activity_id] = (activity_type, fields[0], fields[1])
        done = 0
        expected = 0
        for _, activity_done, activity_expected in self._progress.values():
            done += activity_done
            expected += activity_expected
        self._done = done
        self._expected = expected

    def _update(self):
        if self._expected <= 0:
            return

        total = max(self._expected, 3)
        fraction = self._done / total

        total_bytes = sum(value[1] for value in self._copy_bytes.values())
        done_bytes = sum(value[0] for value in self._copy_bytes.values())
        if total_bytes > 0:
            fraction += (done_bytes / total_bytes) * (len(self._copy_bytes) / total)

        fraction = max(0.0, min(1.0, fraction))

        if fraction >= self._floor:
            self._floor = fraction
            self._floor_done = self._done
        else:
            new_items = self._done - self._floor_done
            remaining = total - self._floor_done
            if remaining > 0 and new_items >= 0:
                fraction = self._floor + (new_items / remaining) * (1.0 - self._floor)
            else:
                fraction = self._floor

        self.fraction = max(self._floor, min(1.0, fraction))


def _total_memory_gib():
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("MemTotal:"):
                    return int(line.split()[1]) / (1024 * 1024)
    except Exception:
        pass
    return 0.0


REQUIRED_FREE_GIB = 16.0
REQUIRED_RAM_GIB = 6.0


def _check_requirements(root_mount_point):
    try:
        stats = os.statvfs(root_mount_point)
        free_gib = stats.f_bfree * stats.f_frsize / (1024 ** 3)
    except OSError:
        free_gib = None

    if free_gib is not None and free_gib < REQUIRED_FREE_GIB:
        return (
            _("Espaço em disco insuficiente"),
            _(
                "O ticoOS precisa de pelo menos {required:.0f} GiB livres na "
                "partição raiz, mas o destino tem apenas {free:.1f} GiB.\n\n"
                "Aumente a partição raiz (recomendado: 20 GiB ou mais) e "
                "tente novamente."
            ).format(required=REQUIRED_FREE_GIB, free=free_gib),
        )

    memory_gib = _total_memory_gib()
    if memory_gib and memory_gib < REQUIRED_RAM_GIB:
        return (
            _("Memória insuficiente"),
            _(
                "O ticoOS precisa de pelo menos {required:.0f} GiB de RAM para "
                "instalar e compilar os pacotes do sistema, mas esta máquina "
                "tem {free:.1f} GiB.\n\n"
                "Aumente a memória da máquina virtual ou use um computador com "
                "mais RAM."
            ).format(required=REQUIRED_RAM_GIB, free=memory_gib),
        )

    return None


def _detect_gpu():
    try:
        output = subprocess.check_output(
            ["lspci", "-nn"],
            stderr=subprocess.DEVNULL,
            text=True,
            errors="replace",
        ).lower()
    except Exception:
        return "auto"

    lines = [
        line
        for line in output.splitlines()
        if any(key in line for key in ("vga", "3d controller", "display controller"))
    ]
    devices = "\n".join(lines)

    if any(key in devices for key in ("virtio", "qxl", "vmware", "virtualbox", "red hat")):
        return "vm"
    if "10de" in devices or "nvidia" in devices:
        return "nvidia" if libcalamares.globalstorage.value("nixos_allow_unfree") else "nouveau"
    if any(key in devices for key in ("1002", "1022", "amd", "ati")):
        return "amd"
    if "8086" in devices or "intel" in devices:
        return "intel"
    return "auto"


def _gpu_module(gpu):
    if gpu == "nvidia":
        return """{ lib, ... }: {
  ticoOS.gpu = "nvidia";
  nixpkgs.config.allowUnfree = true;
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = lib.mkDefault false;
  };
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];
}
"""
    if gpu == "amd":
        return """{ ... }: {
  ticoOS.gpu = "amd";
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];
}
"""
    if gpu == "intel":
        return """{ ... }: {
  ticoOS.gpu = "intel";
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];
}
"""
    if gpu == "vm":
        return """{ ... }: {
  ticoOS.gpu = "vm";
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];
}
"""
    if gpu == "nouveau":
        return """{ ... }: {
  ticoOS.gpu = "nouveau";
  hardware.graphics.enable = true;
}
"""
    return """{ ... }: {
  ticoOS.gpu = "auto";
  hardware.graphics.enable = true;
}
"""


def _boot_module(firmware_type, boot_device, root_is_btrfs):
    if firmware_type == "efi":
        return """{ ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
"""

    if boot_device and boot_device != "nodev":
        text = (
            "{ ... }: {\n"
            "  boot.loader.grub.enable = true;\n"
            '  boot.loader.grub.device = "' + boot_device + '";\n'
            "  boot.loader.grub.useOSProber = true;\n"
        )
        if root_is_btrfs:
            text += '  boot.loader.grub.fsIdentifier = "provided";\n'
        return text + "}\n"

    return """{ ... }: {
  boot.loader.grub.enable = false;
}
"""


def _write(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def _nix_string(value):
    return json.dumps(value, ensure_ascii=False)


def _install(root_mount_point):
    global status

    nixos_directory = os.path.join(root_mount_point, "etc", "nixos")

    status = _("Generating hardware configuration")
    libcalamares.job.setprogress(0.03)
    subprocess.check_output(
        _elevated(["nixos-generate-config", "--root", root_mount_point]),
        stderr=subprocess.STDOUT,
    )

    status = _("Writing ticoOS local configuration")
    libcalamares.job.setprogress(0.06)
    os.makedirs(nixos_directory, exist_ok=True)

    gs = libcalamares.globalstorage
    username = gs.value("username") or "tico"
    fullname = gs.value("fullname") or username
    hostname = gs.value("hostname") or "ticoOS"
    firmware_type = gs.value("firmwareType") or "bios"
    boot_loader = gs.value("bootLoader") or {}
    boot_device = boot_loader.get("installPath") if isinstance(boot_loader, dict) else None
    partitions = gs.value("partitions") or []
    root_is_btrfs = any(
        partition.get("mountPoint") == "/" and partition.get("fs") == "btrfs"
        for partition in partitions
    )
    gpu = _detect_gpu()

    local_directory = os.path.join(nixos_directory, "local")
    os.makedirs(local_directory, exist_ok=True)

    generated_hardware = os.path.join(nixos_directory, "hardware-configuration.nix")
    if os.path.exists(generated_hardware):
        os.replace(
            generated_hardware,
            os.path.join(local_directory, "hardware-configuration.nix"),
        )

    _write(
        os.path.join(nixos_directory, "flake.nix"),
        '''{
  inputs.ticoos.url = "github:ticoOS/ticoOS-NIX/stable";
  outputs = { self, ticoos, ... }: {
    nixosConfigurations.ticoOS = ticoos.lib.mkSystem {
      modules = [ ./local ];
    };
  };
}
''',
    )

    _write(
        os.path.join(local_directory, "hostname.nix"),
        '{{ ... }}: {{\n  networking.hostName = {};\n}}\n'.format(
            _nix_string(hostname)
        ),
    )
    _write(
        os.path.join(local_directory, "boot.nix"),
        _boot_module(firmware_type, boot_device, root_is_btrfs),
    )
    _write(
        os.path.join(local_directory, "gpu.nix"),
        _gpu_module(gpu),
    )
    _write(
        os.path.join(local_directory, "default.nix"),
        '''{{ ... }}: {{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./hostname.nix
    ./gpu.nix
  ];
  ticoOS.username = {};
  ticoOS.fullname = {};
  ticoOS.autoUpdate.enable = false;
}}
'''.format(_nix_string(username), _nix_string(fullname)),
    )

    libcalamares.utils.debug(
        "ticoOS: firmware={} boot_device={} gpu={} user={}".format(
            firmware_type, boot_device, gpu, username
        )
    )

    requirement_error = _check_requirements(root_mount_point)
    if requirement_error:
        return requirement_error

    status = _("Locking ticoOS configuration")
    libcalamares.job.setprogress(0.08)
    subprocess.check_output(
        _elevated(
            [
                "nix",
                "--extra-experimental-features",
                "nix-command flakes",
                "flake",
                "lock",
            ]
        ),
        cwd=nixos_directory,
        stderr=subprocess.STDOUT,
    )

    status = _("Installing ticoOS")
    libcalamares.job.setprogress(0.1)

    install_options = [
        "--option",
        "build-dir",
        "/nix/var/nix/builds",
        "--option",
        "fallback",
        "true",
    ]
    memory_gib = _total_memory_gib()
    if memory_gib < 7.5:
        install_options.extend(
            [
                "--option",
                "max-jobs",
                "1",
                "--option",
                "cores",
                "1",
            ]
        )
    libcalamares.utils.debug(
        "ticoOS: memory={:.1f} GiB low_memory={}".format(memory_gib, memory_gib < 7.5)
    )

    command = _elevated(
        _proxy_environment()
        + [
            "nixos-install",
            "--flake",
            nixos_directory + "#ticoOS",
            "--root",
            root_mount_point,
            "--no-root-passwd",
            "--log-format",
            "internal-json",
        ]
        + install_options
    )

    progress = NixProgress()
    output = []
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    for raw_line in iter(process.stdout.readline, b""):
        line = raw_line.decode("utf-8", errors="replace")
        if progress.handle(line):
            for message in progress.messages:
                output.append(message + "\n")
                libcalamares.utils.debug("nixos-install: {}".format(message))
            progress.messages.clear()
        else:
            output.append(line)
            libcalamares.utils.debug("nixos-install: {}".format(line.rstrip()))
        libcalamares.job.setprogress(0.1 + progress.fraction * 0.9)

    exit_code = process.wait()
    if exit_code != 0:
        return (_("nixos-install failed"), "".join(output))

    libcalamares.job.setprogress(1.0)
    return None


def run():
    try:
        root_mount_point = libcalamares.globalstorage.value("rootMountPoint")
        if not root_mount_point:
            raise RuntimeError("rootMountPoint was not provided by Calamares")
        return _install(root_mount_point)
    except Exception:
        details = traceback.format_exc()
        libcalamares.utils.error(details)
        return (_("ticoOS installation failed"), details)
