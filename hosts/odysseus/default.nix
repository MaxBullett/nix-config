{
  hostName,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Declare normal users early so they can be passed on to modules
  _module.args.hostUsers = [ "max" ];

  imports = lib.flatten [
    # Hardware
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402
    ./hardware.nix

    # Disk
    inputs.disko.nixosModules.disko
    ./disko.nix

    (map lib.custom.relativeToRoot [
      # Required modules
      "modules/nixos/common"

      # Optional modules
      "modules/nixos/plymouth.nix"
    ])
  ];

  boot = {
    initrd.systemd.enable = true;
    kernelPackages = pkgs.unstable.linuxPackages_latest;
    kernelParams = [ ];
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = lib.mkDefault 5;
      systemd-boot = {
        enable = true;
        configurationLimit = lib.mkDefault 10;
      };
    };
  };

  networking = {
    inherit hostName;
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  system.stateVersion = "25.05";
}
