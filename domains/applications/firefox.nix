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

  # Collect all users with Firefox enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.applications.firefox.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
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

          # Enable hardware acceleration for AMD GPU
          profiles.default = mkIf cfg.enableHardwareAcceleration {
            id = 0;
            isDefault = true;
            settings = {
              "media.ffmpeg.vaapi.enabled" = true;
              "media.hardware-video-decoding.force-enabled" = true;
              "media.rdd-ffmpeg.enabled" = true;
              "widget.dmabuf.force-enabled" = true;
              "gfx.webrender.all" = true;
            };
          };
        };
      };
    };
in
{
  config = mkMerge [
    # Inject the Firefox home-manager module into all users
    {
      home-manager.sharedModules = [ firefoxHomeModule ];
    }

    # System-level configuration when any user has Firefox enabled
    (mkIf anyEnabled {
      # Ensure Firefox is available system-wide
      environment.systemPackages = [ pkgs.firefox ];

      # Enable hardware acceleration support
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    # Conditional persistence for all enabled users
    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/preserve" = {
        users = mapAttrs (username: _: {
          directories = [
            # Firefox profile data preserved across reboots
            # Includes Mozilla account login and synced settings
            ".mozilla/firefox"
          ];
        }) enabledUsers;
      };
    })
  ];
}
