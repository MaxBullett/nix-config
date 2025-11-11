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

  cfg = config.domains.system.time-sync;
in
{
  options.domains.system.time-sync = {
    enable = mkEnableOption "systemd-timesyncd NTP time synchronization";

    servers = mkOption {
      type = types.listOf types.str;
      default = [
        "time.cloudflare.com"
        "pool.ntp.org"
      ];
      description = ''
        NTP servers to use for time synchronization.
        Default includes Cloudflare's fast NTP service and the public NTP pool.
      '';
      example = [
        "0.pool.ntp.org"
        "1.pool.ntp.org"
      ];
    };
  };

  config = mkIf cfg.enable {
    services.timesyncd = {
      enable = true;
      inherit (cfg) servers;
    };
  };
}
