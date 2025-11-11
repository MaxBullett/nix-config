{
  config,
  lib,
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

  cfg = config.domains.desktop.cosmic;

  normalUsers = filterAttrs (_: user: user.isNormalUser or false) config.users.users;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;
in
{
  options.domains.desktop.cosmic = {
    enable = mkEnableOption "COSMIC desktop environment";

    cosmic-greeter = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the COSMIC greeter (display manager).";
      };
    };

    xwayland = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable XWayland support for COSMIC.";
      };
    };

    autoLogin = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable auto login for the greeter.";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Username to auto login as when autoLogin is enabled.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion =
            !(cfg.enable && cfg.autoLogin.enable) || (cfg.autoLogin.user != null && cfg.autoLogin.user != "");
          message = "domains.desktop.cosmic.autoLogin.user must be set when autoLogin.enable = true.";
        }
      ];

      services.displayManager = {
        inherit (cfg) cosmic-greeter;

        autoLogin = mkIf cfg.autoLogin.enable {
          enable = true;
          inherit (cfg.autoLogin) user;
        };
      };

      services.desktopManager.cosmic = {
        enable = true;
        inherit (cfg) xwayland;
      };

      # Fix clipboard issues in COSMIC
      environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

      # Required for desktop privilege operations (mounting, power management, etc.)
      security.polkit.enable = true;
    })

    # Conditional persistence for all normal users
    (mkIf (cfg.enable && preservationEnabled) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            # COSMIC desktop settings and state
            ".config/cosmic"
            ".local/state/cosmic"
            ".local/state/cosmic-comp"

            # Initial setup flag
            ".config/cosmic-initial-setup-done"

            # Pop Launcher (app launcher) history and preferences
            ".local/state/pop-launcher"
          ];
        }) normalUsers;
      };
    })
  ];
}
