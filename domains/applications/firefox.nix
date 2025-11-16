{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.applications.firefox.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  firefoxHomeModule =
    { config, ... }:
    let
      cfg = config.domains.applications.firefox;
    in
    {
      options.domains.applications.firefox = {
        enable = mkEnableOption "Firefox web browser";

        enableHardwareAcceleration = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Enable hardware video acceleration (VA-API).
            Recommended for AMD/Intel GPUs for better video playback performance.
          '';
        };
      };

      config = mkIf cfg.enable {
        programs.firefox = {
          enable = true;

          profiles.default = {
            id = 0;
            isDefault = true;
            settings = mkIf cfg.enableHardwareAcceleration {
              "media.ffmpeg.vaapi.enabled" = true;
              "media.hardware-video-decoding.force-enabled" = true;
              "media.rdd-ffmpeg.enabled" = true;
              "widget.dmabuf.force-enabled" = true;
              "gfx.webrender.all" = true;
            };
          };
        };

        # Tell Stylix which Firefox profile to theme (harmless if Stylix not enabled)
        stylix.targets.firefox.profileNames = [ "default" ];
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ firefoxHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.firefox ];

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".mozilla"
          ];
        }) enabledUsers;
      };
    })
  ];
}
