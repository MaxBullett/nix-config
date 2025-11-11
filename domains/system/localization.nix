{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.domains.system.localization;
in
{
  options.domains.system.localization = {
    timeZone = mkOption {
      type = types.str;
      description = "The system time zone.";
      example = "Europe/Berlin";
    };

    defaultLocale = mkOption {
      type = types.str;
      description = "The default locale for the system.";
      example = "en_US.UTF-8";
    };

    extraLocaleSettings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional locale-specific settings (LC_* variables).";
      example = {
        LC_TIME = "en_DK.UTF-8";
      };
    };

    keyboardLayout = mkOption {
      type = types.str;
      description = "The keyboard layout for the console.";
      example = "us";
    };
  };

  config = {
    time.timeZone = cfg.timeZone;

    i18n = {
      inherit (cfg) defaultLocale extraLocaleSettings;
    };

    console.keyMap = cfg.keyboardLayout;
  };
}
