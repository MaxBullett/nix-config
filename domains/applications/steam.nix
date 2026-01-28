{
  config,
  l,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.domains.applications.steam;

  normalUsers = l.getNormalUsers config;
in
{
  options.domains.applications.steam = {
    enable = mkEnableOption "Steam gaming platform";

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
        Additional compatibility tool packages (e.g., Proton GE).
        These will be available in Steam's compatibility tools list.
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
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

    (mkIf (cfg.enable && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            # Steam library and game data
            ".local/share/Steam"
            # Steam configuration and cached metadata
            ".steam"
            # Game/Publisher-specific local files to potentially persist
            ".local/share/Paradox Interactive"
          ];
        }) normalUsers;
      };
    })
  ];
}
