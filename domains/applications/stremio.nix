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
    _: userCfg: userCfg.domains.applications.stremio.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  stremioHomeModule = {
    options.domains.applications.stremio = {
      enable = mkEnableOption "Stremio media center";
    };
  };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ stremioHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.stremio-linux-shell ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".stremio-server"
            ".local/share/stremio"
          ];
        }) enabledUsers;
      };
    })
  ];
}
