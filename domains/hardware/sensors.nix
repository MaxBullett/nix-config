{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.domains.hardware.sensors;
in
{
  options.domains.hardware.sensors = {
    enable = mkEnableOption "hardware monitoring with lm_sensors";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.lm_sensors ];
  };
}
