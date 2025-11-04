{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.domains.system.zram;
in
{
  options.domains.system.zram = {
    enable = mkEnableOption "zram compressed swap in RAM";

    memoryPercent = mkOption {
      type = types.int;
      default = 10;
      description = ''
        Percentage of RAM to use for zram swap.

        Default: 10% (e.g., 1.6GB on 16GB system)
        Higher values trade CPU for memory capacity.
      '';
    };

    priority = mkOption {
      type = types.int;
      default = 100;
      description = ''
        Swap priority (higher = preferred over other swap).

        Default: 100 (higher than typical disk swap at 0)
      '';
    };
  };

  config = mkIf cfg.enable {
    zramSwap = {
      enable = true;
      inherit (cfg) memoryPercent priority;
    };
  };
}
