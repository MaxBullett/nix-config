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
  cfg = config.domains.system.journald;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;
in
{
  options.domains.system.journald = {
    enable = mkEnableOption "systemd journal configuration";

    storage = mkOption {
      type = types.enum [
        "persistent"
        "volatile"
        "auto"
        "none"
      ];
      default = if preservationEnabled then "persistent" else "auto";
      description = ''
        Where to store journal logs:
        - persistent: Only in /var/log/journal (survives reboots)
        - volatile: Only in /run/log/journal (RAM, lost on reboot)
        - auto: Persistent if /var/log/journal exists, else volatile
        - none: Don't keep logs

        Default: "persistent" when preservation enabled, "auto" otherwise
      '';
    };

    maxSize = mkOption {
      type = types.str;
      default = "1G";
      description = ''
        Maximum disk space the journal can use.

        Prevents the journal from consuming too much space.
        Especially important for ephemeral root systems.

        Examples: "500M", "1G", "2G"
      '';
    };

    maxRetentionSec = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Delete logs older than this duration.

        Prevents old logs from accumulating in persistent storage.

        Examples: "1month", "2weeks", "7d"
      '';
      example = "1month";
    };

    maxFileSec = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Maximum time to store entries in a single journal file before rotating.

        Helps with log organization and cleanup.

        Examples: "1week", "1day", "1month"
      '';
      example = "1week";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Additional journald configuration.

        See journald.conf(5) for available options.
      '';
      example = ''
        Compress=yes
        RateLimitBurst=10000
      '';
    };
  };

  config = mkIf cfg.enable {
    services.journald.extraConfig = ''
      Storage=${cfg.storage}
      SystemMaxUse=${cfg.maxSize}
      ${lib.optionalString (cfg.maxRetentionSec != null) "MaxRetentionSec=${cfg.maxRetentionSec}"}
      ${lib.optionalString (cfg.maxFileSec != null) "MaxFileSec=${cfg.maxFileSec}"}
      ${cfg.extraConfig}
    '';

    # Conditional persistence: /var/log when using persistent storage
    domains.storage.btrfs.preservation.mounts."/persist".directories = mkIf (
      preservationEnabled && cfg.storage == "persistent"
    ) [ "/var/log" ];
  };
}
