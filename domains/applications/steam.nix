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

  # Collect all users with Steam enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.applications.steam.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
  steamHomeModule =
    { config, ... }:
    let
      cfg = config.domains.applications.steam;
    in
    {
      options.domains.applications.steam = {
        enable = mkEnableOption "Steam gaming platform";

        extraCompatPackages = mkOption {
          type = with types; listOf package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.proton-ge-bin ]";
          description = ''
            Additional compatibility tool packages (e.g., Proton GE).

            These will be available in Steam's compatibility tools list.
          '';
        };
      };

      config = mkIf cfg.enable {
        # Per-user Steam configuration can be added here if needed
        # Most Steam config is handled at the system level
      };
    };

  cfg = config.domains.applications.steam or { };
in
{
  options.domains.applications.steam = {
    remotePlay = {
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Open firewall ports for Steam Remote Play.

          Allows streaming games from this machine to other devices.
        '';
      };
    };

    dedicatedServer = {
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Open firewall ports for Source Dedicated Server.

          Required for hosting game servers (TF2, CS:GO, etc.).
        '';
      };
    };

    gamemode = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Feral Interactive's GameMode for performance optimization.

          GameMode temporarily applies optimizations when games are running.
        '';
      };
    };

    extraCompatPackages = mkOption {
      type = with types; listOf package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.proton-ge-bin ]";
      description = ''
        System-wide additional compatibility tool packages (e.g., Proton GE).

        These will be available in Steam's compatibility tools list for all users.
      '';
    };
  };

  config = mkMerge [
    # Inject the Steam home-manager module into all users
    {
      home-manager.sharedModules = [ steamHomeModule ];
    }

    # System-level configuration when any user has Steam enabled
    (mkIf anyEnabled {
      # Enable Steam with hardware acceleration and 32-bit support
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = cfg.remotePlay.openFirewall or false;
        dedicatedServer.openFirewall = cfg.dedicatedServer.openFirewall or false;

        # Include extra compatibility packages
        extraCompatPackages = cfg.extraCompatPackages;
      };

      # Enable GameMode for performance optimization
      programs.gamemode.enable = mkIf (cfg.gamemode.enable or true) true;

      # Ensure graphics drivers and 32-bit support
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    # Conditional persistence for all enabled users
    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            # Steam library and game data
            ".local/share/Steam"
            # Steam configuration and cached metadata
            ".steam"
          ];
        }) enabledUsers;
      };
    })
  ];
}
