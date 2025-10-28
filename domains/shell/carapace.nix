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

  # Collect all users with carapace enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.shell.carapace.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
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
        # Carapace has no configuration files - just needs to be available
        # Shell integration is handled by the shell domain (e.g., nushell)
        home.packages = [ pkgs.carapace ];
      };
    };
in
{
  config = mkMerge [
    # Inject the carapace home-manager module into all users
    {
      home-manager.sharedModules = [ carapaceHomeModule ];
    }

    # System-level configuration when any user has carapace enabled
    (mkIf anyEnabled {
      # Ensure carapace is available system-wide
      environment.systemPackages = [ pkgs.carapace ];
    })

    # Conditional persistence for all enabled users
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
