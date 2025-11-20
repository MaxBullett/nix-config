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
    _: userCfg: userCfg.domains.shell.zoxide.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  zoxideHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.shell.zoxide;
    in
    {
      options.domains.shell.zoxide = {
        enable = mkEnableOption "zoxide smarter cd command";
      };

      config = mkIf cfg.enable {
        programs.zoxide = {
          enable = true;
          enableNushellIntegration = config.domains.shell.nushell.enable or false;
        };

        # Install zoxide in home.packages to ensure it's available when nushell starts
        home.packages = [ pkgs.zoxide ];
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ zoxideHomeModule ];
    }

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".local/share/zoxide"
          ];
        }) enabledUsers;
      };
    })
  ];
}
