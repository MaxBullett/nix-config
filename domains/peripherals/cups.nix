{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.domains.peripherals.cups;
in
{
  options.domains.peripherals.cups = {
    enable = mkEnableOption "CUPS printing system";

    drivers = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        cups-filters
        cups-browsed
      ];
      description = "Printer drivers and filters to install.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.printing = {
        enable = true;
        inherit (cfg) drivers;
      };
    }

    (mkIf config.domains.storage.btrfs.preservation.enable {
      domains.storage.btrfs.preservation.mounts."/persist".directories = [
        "/var/lib/cups"
        "/var/cache/cups"
      ];
    })
  ]);
}
