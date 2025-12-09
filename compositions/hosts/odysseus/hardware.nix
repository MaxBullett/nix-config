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

  systemd.sleep.extraConfig = ''
    HibernateDefibrillatorSec=20s
    SuspendState=mem
    HibernateMode=platform shutdown
    HibernateState=disk
    HibernateDelaySec=3600
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  # Upstream issue causing asusd spam
  systemd.services.asusd.serviceConfig.LogLevelMax = "warning";
}
