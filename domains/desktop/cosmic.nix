{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.domains.desktop.cosmic;
in
{
  options.domains.desktop.cosmic = {
    enable = mkEnableOption "COSMIC desktop environment";

    greeter = {
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

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          !(cfg.enable && cfg.autoLogin.enable) || (cfg.autoLogin.user != null && cfg.autoLogin.user != "");
        message = "domains.desktop.cosmic.autoLogin.user must be set when autoLogin.enable = true.";
      }
    ];

    services.displayManager = {
      cosmic-greeter.enable = cfg.greeter.enable;
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
  };
}
