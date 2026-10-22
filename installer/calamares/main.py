#!/usr/bin/env python3
"""Calamares module that installs ticoOS from the embedded flake."""

import os
import subprocess
import tempfile

import libcalamares

status = "Installing ticoOS"


def pretty_name():
    return "Installing ticoOS"


def pretty_status_message():
    return status


def _unobscure(value):
    """Reverse Calamares' password obscuring."""
    if not value:
        return ""
    return "".join(
        chr(0x1001F - ord(char)) if ord(char) > 0x21 else char
        for char in value
    )


def _nix_string(value):
    value = str(value)
    value = value.replace("\\", "\\\\")
    value = value.replace('"', '\\"')
    value = value.replace("${", "\\${")
    value = value.replace("\n", "\\n")
    value = value.replace("\r", "\\r")
    value = value.replace("\t", "\\t")
    return '"' + value + '"'


def _vconsole_keymap(layout, variant):
    try:
        with open("/run/current-system/sw/share/systemd/kbd-model-map", "r") as handle:
            rows = []
            for line in handle:
                if line.startswith("#") or not line.strip():
                    continue
                columns = line.split()
                if len(columns) >= 4 and columns[1] == layout:
                    rows.append(columns)
    except OSError:
        return None

    if not rows:
        return None

    if variant:
        for columns in rows:
            if columns[2] == variant or variant in columns[3]:
                return columns[0]

    return rows[0][0]


def _write_file_at_root(root, relative_path, contents):
    target = os.path.join(root, relative_path)
    temp = tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir="/tmp",
        delete=False,
    )
    try:
        temp.write(contents)
        temp.close()
        subprocess.check_call(["pkexec", "cp", temp.name, target])
    finally:
        try:
            os.unlink(temp.name)
        except OSError:
            pass


def _build_user_config(gs):
    username = gs.value("username") or "tico"
    fullname = gs.value("fullname") or username
    password = _unobscure(gs.value("password") or "") or "123"

    hostname = gs.value("hostname") or "ticoOS"
    region = gs.value("locationRegion")
    zone = gs.value("locationZone")
    locale_conf = gs.value("localeConf") or {}
    language = locale_conf.get("LANG")
    layout = gs.value("keyboardLayout")
    variant = gs.value("keyboardVariant") or ""
    vconsole = _vconsole_keymap(layout, variant) if layout else None

    lines = [
        "{ lib, ... }:",
        "{",
        f"  ticoOS.username = {_nix_string(username)};",
        "",
        f"  users.users.{_nix_string(username)} = {{",
        "    isNormalUser = true;",
        f"    description = {_nix_string(fullname)};",
        '    extraGroups = [ "wheel" "networkmanager" "video" "render" "audio" ];',
        f"    initialPassword = {_nix_string(password)};",
        "  };",
        "",
        f"  networking.hostName = {_nix_string(hostname)};",
    ]

    if language:
        lines.append(f"  i18n.defaultLocale = {_nix_string(language)};")

    if region and zone:
        lines.append(f"  time.timeZone = {_nix_string(region + '/' + zone)};")

    if layout:
        lines.extend(
            [
                "  services.xserver.xkb = {",
                f"    layout = {_nix_string(layout)};",
                f"    variant = {_nix_string(variant)};",
                "  };",
            ]
        )

    if vconsole:
        lines.append(f"  console.keyMap = {_nix_string(vconsole)};")

    firmware = gs.value("firmwareType")
    boot_loader = gs.value("bootLoader") or {}
    install_path = boot_loader.get("installPath") if isinstance(boot_loader, dict) else None

    if firmware == "efi":
        lines.extend(
            [
                "  boot.loader.systemd-boot.enable = true;",
                "  boot.loader.efi.canTouchEfiVariables = true;",
            ]
        )
    elif install_path:
        lines.extend(
            [
                "  boot.loader.grub.enable = true;",
                f"  boot.loader.grub.device = {_nix_string(install_path)};",
                "  boot.loader.grub.useOSProber = true;",
            ]
        )
    else:
        lines.append("  boot.loader.grub.enable = false;")

    lines.append("}")
    return "\n".join(lines) + "\n"


def run():
    global status

    gs = libcalamares.globalstorage
    root = gs.value("rootMountPoint")
    if not root:
        return ("Installation failed", "rootMountPoint is missing")

    nixos_dir = os.path.join(root, "etc/nixos")
    flake_source = "/etc/ticoos-installer/flake"

    status = "Copying ticoOS flake"
    libcalamares.job.setprogress(0.05)
    try:
        subprocess.check_call(["pkexec", "mkdir", "-p", nixos_dir])
        subprocess.check_call(
            ["pkexec", "cp", "-aL", flake_source + "/.", nixos_dir + "/"]
        )
    except (OSError, subprocess.CalledProcessError) as error:
        return ("Could not copy ticoOS flake", str(error))

    status = "Generating hardware configuration"
    libcalamares.job.setprogress(0.2)
    try:
        subprocess.check_call(
            ["pkexec", "nixos-generate-config", "--root", root]
        )
    except (OSError, subprocess.CalledProcessError) as error:
        return ("nixos-generate-config failed", str(error))

    status = "Writing Calamares user configuration"
    libcalamares.job.setprogress(0.3)
    try:
        _write_file_at_root(
            root,
            "etc/nixos/calamares-user.nix",
            _build_user_config(gs),
        )
    except (OSError, subprocess.CalledProcessError) as error:
        return ("Could not write Calamares user configuration", str(error))

    status = "Installing ticoOS"
    libcalamares.job.setprogress(0.35)

    command = [
        "pkexec",
        "nixos-install",
        "--root",
        root,
        "--no-root-passwd",
        "--flake",
        nixos_dir + "#ticoOS",
        "--option",
        "build-dir",
        "/nix/var/nix/builds",
    ]

    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
        )
        output = []
        assert process.stdout is not None
        for line in process.stdout:
            output.append(line)
            libcalamares.utils.debug("nixos-install: " + line.rstrip())
        exit_code = process.wait()
    except OSError as error:
        return ("nixos-install failed", str(error))

    if exit_code != 0:
        return ("nixos-install failed", "".join(output))

    libcalamares.job.setprogress(1.0)
    return None
