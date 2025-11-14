{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.domains.boot.plymouth;
in
{
  options.domains.boot.plymouth = {
    enable = mkEnableOption "Plymouth boot splash screen";
  };

  config = mkIf cfg.enable {
    boot = {
      plymouth.enable = true;

      # Kernel parameters needed for Plymouth to work properly
      kernelParams = [
        "quiet"
        "splash"
        "vt.global_cursor_default=0"
      ];

      # Reduce console log level for cleaner boot
      consoleLogLevel = 3;
    };
  };
}
