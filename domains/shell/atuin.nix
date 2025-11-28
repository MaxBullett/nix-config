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
    _: userCfg: userCfg.domains.shell.atuin.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  atuinHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.shell.atuin;
    in
    {
      options.domains.shell.atuin = {
        enable = mkEnableOption "atuin magical shell history";

        sync = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable atuin sync.";
          };

          keyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Path to the atuin encryption key file (from SOPS).
              If null, you must run 'atuin login' or 'atuin register' manually.
            '';
          };

          sessionFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Path to the atuin session token file (from SOPS).
              If null, you must run 'atuin login' manually.
            '';
          };
        };
      };

      config = mkIf cfg.enable (
        lib.mkMerge [
          {
            programs.atuin = {
              enable = true;
              enableNushellIntegration = config.domains.shell.nushell.enable or false;

              settings = {
                # Search settings
                search_mode = "fuzzy";
                filter_mode = "global";
                enter_accept = true;

                # Sync settings
                auto_sync = cfg.sync.enable;
                sync_frequency = if cfg.sync.enable then "10m" else "0";
                sync_address = if cfg.sync.enable then "https://api.atuin.sh" else "";

                # UI settings
                dialect = "uk";
                inline_height = 20;
                show_preview = true;
                style = "compact";

                # History settings
                update_check = false;
              }
              // lib.optionalAttrs (cfg.sync.enable && cfg.sync.keyFile != null) {
                #key_path = cfg.sync.keyFile;
              }
              // lib.optionalAttrs (cfg.sync.enable && cfg.sync.sessionFile != null) {
                #session_path = cfg.sync.sessionFile;
              };
            };

            # Install atuin in home.packages to ensure it's available when nushell starts
            home.packages = [ pkgs.atuin ];
          }
        ]
      );
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ atuinHomeModule ];
    }

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".local/share/atuin"
            ".config/atuin"
          ];
        }) enabledUsers;
      };
    })
  ];
}
