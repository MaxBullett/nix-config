{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.domains.peripherals.keychron;
in
{
  options.domains.peripherals.keychron = {
    enable = mkEnableOption "udev rules for Keychron devices (WebHID launcher access)";
  };

  config = mkIf cfg.enable {
    # Shipped as a package so the rule lands in lib/udev/rules.d with a low
    # number: `uaccess` must be set before 73-seat-late.rules, which
    # `services.udev.extraRules` (99-local.rules) is too late for.
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "keychron-udev-rules";
        destination = "/lib/udev/rules.d/70-keychron.rules";
        text = ''
          # Keychron (USB vendor 3434): grant the active seat user hidraw access
          # so launcher.keychron.com can talk to the device over WebHID.
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"
        '';
      })
    ];
  };
}
