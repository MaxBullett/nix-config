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

  # Auto-detect if COSMIC greeter is enabled for PAM integration
  cosmicGreeterEnabled = config.services.displayManager.cosmic-greeter.enable or false;

  # Determine PAM service to integrate with
  pamService =
    if cosmicGreeterEnabled then
      "cosmic-greeter"
    else if cfg.pamService != null then
      cfg.pamService
    else
      null;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;

  # Find all normal (non-system) users who will use the keyring
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

    sshAgent = {
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

    gui = {
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

    # Enable GNOME Keyring service
    services.gnome.gnome-keyring.enable = true;

    # PAM integration with display manager
    security.pam.services.${pamService}.enableGnomeKeyring = true;

    # Optional: SSH agent integration
    services.gnome.gcr-ssh-agent.enable = mkIf cfg.sshAgent.enable true;

    # Optional: Seahorse GUI
    programs.seahorse.enable = mkIf cfg.gui.enable true;

    # Conditional persistence
    domains.storage.btrfs.preservation.mounts = mkIf preservationEnabled {
      "/persist" = {
        # System-wide keyring data
        directories = [ "/var/lib/gnome-keyring" ];

        # Per-user keyring data (for all normal users)
        users = mapAttrs (username: _: {
          directories = [ ".local/share/keyrings" ];
        }) normalUsers;
      };
    };
  };
}
