{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.domains.hardware.firmware;
in
{
  options.domains.hardware.firmware = {
    enable = mkEnableOption "fwupd firmware update service";
  };

  config = mkIf cfg.enable {
    services.fwupd.enable = true;
  };
}
