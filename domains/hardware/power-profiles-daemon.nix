{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.domains.hardware.power-profiles-daemon;
in
{
  options.domains.hardware.power-profiles-daemon = {
    enable = mkEnableOption "power-profiles-daemon for power profile management";
  };

  config = mkIf cfg.enable {
    services.power-profiles-daemon.enable = true;
  };
}
