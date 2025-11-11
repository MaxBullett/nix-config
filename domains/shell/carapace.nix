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
    _: userCfg: userCfg.domains.shell.carapace.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  carapaceHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.shell.carapace;
    in
    {
      options.domains.shell.carapace = {
        enable = mkEnableOption "carapace multi-shell completion generator";
      };

      config = mkIf cfg.enable {
        home.packages = [ pkgs.carapace ];
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ carapaceHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.carapace ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".cache/carapace"
          ];
        }) enabledUsers;
      };
    })
  ];
}
