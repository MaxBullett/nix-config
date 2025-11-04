{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;
  cfg = config.domains.security.doas;
in
{
  options.domains.security.doas = {
    enable = mkEnableOption "doas privilege escalation (sudo alternative)";

    # Wheel group configuration (matches security.doas.extraRules attributes)
    wheel = {
      noPass = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Allow wheel group to execute commands without password.

          When false (default), password required (more secure).
          When true, no password needed (use with caution).
        '';
      };

      persist = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Cache authentication credentials for 5 minutes.

          Similar to sudo's default behavior. Reduces password prompts
          for consecutive privileged operations.
        '';
      };

      keepEnv = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Preserve the user's environment when escalating.

          Useful for keeping variables like EDITOR, PAGER, etc.
          Set to false for stricter security.
        '';
      };
    };

    allowPowerCommands = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Allow wheel group to execute power commands without password.

        Adds nopass rules for: reboot, poweroff, shutdown.
        Convenient for laptops/desktops where you want quick power control.
      '';
    };

    extraRules = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = ''
        Additional doas rules beyond the default wheel group rule.

        See nixos options documentation for security.doas.extraRules format.
      '';
      example = [
        {
          users = [ "myuser" ];
          noPass = true;
          cmd = "reboot";
        }
      ];
    };
  };

  config = mkIf cfg.enable {
    # Disable sudo when doas is enabled
    security.sudo.enable = false;

    # Create sudo wrapper for compatibility (muscle memory + tools that hardcode sudo)
    environment.systemPackages = [
      (pkgs.writeScriptBin "sudo" ''exec doas "$@"'')
    ];

    security.doas = {
      enable = true;

      # Build rules list
      extraRules = mkMerge [
        # Default rule for wheel group
        [
          {
            groups = [ "wheel" ];
            inherit (cfg.wheel)
              noPass
              persist
              keepEnv
              ;
          }
        ]

        # Power commands without password
        (mkIf cfg.allowPowerCommands [
          {
            groups = [ "wheel" ];
            noPass = true;
            cmd = "reboot";
          }
          {
            groups = [ "wheel" ];
            noPass = true;
            cmd = "poweroff";
          }
          {
            groups = [ "wheel" ];
            noPass = true;
            cmd = "shutdown";
          }
        ])

        # User-provided extra rules
        cfg.extraRules
      ];
    };
  };
}
