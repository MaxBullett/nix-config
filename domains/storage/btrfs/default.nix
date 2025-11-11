{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.domains.storage.btrfs;
in
{
  imports = [
    ./preservation.nix
    ./snapshots.nix
  ];

  options.domains.storage.btrfs = {
    enable = mkEnableOption "Btrfs defaults and maintenance tasks.";

    autoScrub = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run systemd timers to scrub all Btrfs filesystems.";
      };
      interval = mkOption {
        type = types.str;
        default = "weekly";
        description = "systemd timer specification for automatic scrubbing.";
        example = "monthly";
      };
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = mkAfter [ "btrfs" ];
    services.btrfs = { inherit (cfg) autoScrub; };
  };
}
