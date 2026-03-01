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
    _: userCfg: userCfg.domains.applications.figma-linux.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  figmaLinuxHomeModule = {
    options.domains.applications.figma-linux = {
      enable = mkEnableOption "Figma desktop application";
    };
  };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ figmaLinuxHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.figma-linux ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/figma-linux"
          ];
        }) enabledUsers;
      };
    })
  ];
}
