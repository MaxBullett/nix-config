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
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.applications.vlc.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  vlcHomeModule = {
    options.domains.applications.vlc = {
      enable = mkEnableOption "VLC media player";
    };
  };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ vlcHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.vlc ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/vlc"
            ".local/share/vlc"
          ];
        }) enabledUsers;
      };
    })
  ];
}
