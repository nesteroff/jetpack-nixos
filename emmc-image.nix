{ jetson-firmware, cfg }: { config, pkgs, modulesPath, lib, ... }:

with lib;

{
  imports = [
    ./modules/default.nix
    (modulesPath + "/profiles/base.nix")
    (modulesPath + "/profiles/installation-device.nix")
    (modulesPath + "/installer/sd-card/sd-image.nix")
  ];

  hardware.nvidia-jetpack = cfg;

  # Avoids a bunch of extra modules we don't have in the tegra_defconfig, like "ata_piix",
  disabledModules = [ (modulesPath + "/profiles/all-hardware.nix") ];

  boot.loader.grub.enable = false;

  sdImage = let
    kernelPath = "${config.boot.kernelPackages.kernel}/" + "${config.system.boot.loader.kernelFile}";
    initrdPath = "${config.system.build.initialRamdisk}/" + "${config.system.boot.loader.initrdFile}";
    fdtPath = "${config.hardware.deviceTree.package}/" + "${config.hardware.nvidia-jetpack.dtbName}";
    extlinux = pkgs.writeText "extlinux.conf" ''
      TIMEOUT 30
      DEFAULT primary

      MENU TITLE NixOS

      LABEL primary
        MENU LABEL primary kernel
        LINUX /boot/${config.system.boot.loader.kernelFile}
        FDT /boot/${config.hardware.nvidia-jetpack.dtbName}
        INITRD /boot/${config.system.boot.loader.initrdFile}
        APPEND init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
    '';
    loader = pkgs.writeText "loader.conf" ''
      default nixos.conf
      timeout 3
    '';
    nixosloader = pkgs.writeText "nixos.conf" ''
      title NixOS
      linux /boot/${config.system.boot.loader.kernelFile}
      initrd /boot/${config.system.boot.loader.initrdFile}
      options init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
      devicetree /boot/${config.hardware.nvidia-jetpack.dtbName}
    '';
  in {
    firmwareSize = 64;
    populateFirmwareCommands = ''
        mkdir -p firmware/EFI/BOOT
        #cp ${jetson-firmware}/L4TLauncher.efi firmware/EFI/BOOT/BOOTAA64.efi
        cp ${jetson-firmware}/L4TLauncher.efi firmware/EFI/BOOT/BOOTAA64-L4T.efi

        # systemd-boot
        cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-bootaa64.efi firmware/EFI/BOOT/BOOTAA64.efi
        mkdir -p firmware/loader/entries
        mkdir -p firmware/boot
        cp ${loader} ./firmware/loader/loader.conf
        cp ${nixosloader} ./firmware/loader/entries/nixos.conf
        cp ${kernelPath} "./firmware/boot/${config.system.boot.loader.kernelFile}"
        cp ${initrdPath} "./firmware/boot/${config.system.boot.loader.initrdFile}"
        cp ${fdtPath} "./firmware/boot/${config.hardware.nvidia-jetpack.dtbName}"
    '';
    postBuildCommands = ''
        cp firmware_part.img $out
        cp root-fs.img $out
    '';
    populateRootCommands = ''
        mkdir -p ./files/boot/extlinux
        cp ${extlinux} ./files/boot/extlinux/extlinux.conf
        cp ${kernelPath} "./files/boot/${config.system.boot.loader.kernelFile}"
        cp ${initrdPath} "./files/boot/${config.system.boot.loader.initrdFile}"
        cp ${fdtPath} "./files/boot/${config.hardware.nvidia-jetpack.dtbName}"
    '';
  };
}
