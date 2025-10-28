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

  # Collect all users with zoxide enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.shell.zoxide.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
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
        # Zoxide requires no configuration files
        # Shell integration is handled by the shell domain (e.g., nushell)
        home.packages = [ pkgs.zoxide ];
      };
    };
in
{
  config = mkMerge [
    # Inject the zoxide home-manager module into all users
    {
      home-manager.sharedModules = [ zoxideHomeModule ];
    }

    # System-level configuration when any user has zoxide enabled
    (mkIf anyEnabled {
      # Ensure zoxide is available system-wide
      environment.systemPackages = [ pkgs.zoxide ];
    })

    # Conditional persistence for all enabled users
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
