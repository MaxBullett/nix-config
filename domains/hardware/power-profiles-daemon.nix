{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    ;

  cfg = config.domains.hardware.power-profiles-daemon;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;
in
{
  options.domains.hardware.power-profiles-daemon = {
    enable = mkEnableOption "power-profiles-daemon for power profile management";
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.power-profiles-daemon.enable = true;
    })

    (mkIf (cfg.enable && preservationEnabled) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        directories = [
          # Selected power profile (performance/balanced/power-saver)
          "/var/lib/power-profiles-daemon"
        ];
      };
    })
  ];
}
