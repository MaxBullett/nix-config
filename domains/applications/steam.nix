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

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.applications.steam.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

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
            These are available in Steam's compatibility tools list.
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
    {
      home-manager.sharedModules = [ steamHomeModule ];
    }

    (mkIf anyEnabled {
      programs = {
        steam = {
          enable = true;
          inherit (cfg)
            dedicatedServer
            extraCompatPackages
            remotePlay
            ;
        };

        inherit (cfg) gamemode;
      };

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

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
