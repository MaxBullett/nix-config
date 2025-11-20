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
    _: userCfg: userCfg.domains.applications.proton-pass.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  protonPassHomeModule = {
    options.domains.applications.proton-pass = {
      enable = mkEnableOption "Proton Pass password manager";
    };
  };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ protonPassHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.proton-pass ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/Proton Pass"
          ];
        }) enabledUsers;
      };
    })
  ];
}
