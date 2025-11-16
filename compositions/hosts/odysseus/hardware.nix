{
  config,
  inputs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usbhid"
        "sdhci_pci"
      ];
      kernelModules = [ "dm-snapshot" ];
    };
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];
    extraModulePackages = [ ];
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Sleep: GA402RK uses s2idle; don't force "deep" sleep mode
  systemd.sleep.extraConfig = ''
    SuspendState=mem
    SuspendMode=
  '';

  # Upstream issue causing asusd spam
  systemd.services.asusd.serviceConfig.LogLevelMax = "warning";
}
