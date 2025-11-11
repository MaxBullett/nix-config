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
    mkOption
    types
    ;
  cfg = config.domains.security.gnome-keyring;

  cosmicGreeterEnabled = config.services.displayManager.cosmic-greeter.enable or false;

  pamService =
    if cosmicGreeterEnabled then
      "cosmic-greeter"
    else if cfg.pamService != null then
      cfg.pamService
    else
      null;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;

  normalUsers = filterAttrs (_: user: user.isNormalUser or false) config.users.users;
in
{
  options.domains.security.gnome-keyring = {
    enable = mkEnableOption "GNOME Keyring secrets management";

    pamService = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        PAM service to integrate gnome-keyring with (usually the display manager).
        Automatically detects COSMIC greeter. Set manually for other greeters.
      '';
      example = "sddm";
    };

    gcr-ssh-agent = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Use GNOME Keyring as SSH agent.
          Provides SSH agent functionality via gcr-ssh-agent, allowing
          SSH keys to be managed through the keyring.
        '';
      };
    };

    seahorse = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Seahorse GUI for managing passwords and keys.
          Provides a graphical interface for viewing and managing
          keyring contents.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pamService != null;
        message = ''
          domains.security.gnome-keyring: No PAM service detected or configured.
          Either enable a supported greeter (COSMIC) or manually set
          domains.security.gnome-keyring.pamService to your greeter's PAM service name.
        '';
      }
    ];

    services.gnome = {
      gnome-keyring.enable = true;
      inherit (cfg) gcr-ssh-agent;
    };

    security.pam.services.${pamService}.enableGnomeKeyring = true;

    programs = {
      inherit (cfg) seahorse;
    };

    domains.storage.btrfs.preservation.mounts = mkIf preservationEnabled {
      "/persist" = {
        directories = [ "/var/lib/gnome-keyring" ];

        users = mapAttrs (username: _: {
          directories = [ ".local/share/keyrings" ];
        }) normalUsers;
      };
    };
  };
}
