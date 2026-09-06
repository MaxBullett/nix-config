{
  config,
  inputs,
  lib,
  modulesPath,
  pkgs,
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

  systemd = {
    sleep.settings.Sleep = {
      HibernateDefibrillatorSec = "20s";
      SuspendState = "mem";
      HibernateMode = "platform shutdown";
      HibernateState = "disk";
      HibernateDelaySec = "3600";
    };

    # Fix HDMI wake issues with planar helium pct2235
    services.force-hdmi-connector = {
      description = "Force HDMI-A-1 on; monitor drops HPD in standby and relights all outputs";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'for f in /sys/class/drm/*-HDMI-A-1/status; do echo on > \"$f\"; done'";
        ExecStop = "${pkgs.bash}/bin/bash -c 'for f in /sys/class/drm/*-HDMI-A-1/status; do echo detect > \"$f\"; done'";
      };
    };
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  # Upstream issue causing asusd spam
  systemd.services.asusd.serviceConfig.LogLevelMax = "warning";
}
