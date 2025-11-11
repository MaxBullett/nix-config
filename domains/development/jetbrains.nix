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
    _: userCfg: userCfg.domains.development.jetbrains.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  jetbrainsHomeModule =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.domains.development.jetbrains;
    in
    {
      options.domains.development.jetbrains = {
        enable = mkEnableOption "JetBrains IDEs";

        ides = mkOption {
          type = with types; listOf package;
          default = [ ];
          description = ''
            List of JetBrains IDEs to install.

            Available IDEs include:
            - pkgs.jetbrains.idea-ultimate (IntelliJ IDEA Ultimate)
            - pkgs.jetbrains.idea-community (IntelliJ IDEA Community)
            - pkgs.jetbrains.pycharm-professional (PyCharm Professional)
            - pkgs.jetbrains.pycharm-community (PyCharm Community)
            - pkgs.jetbrains.webstorm (WebStorm)
            - pkgs.jetbrains.phpstorm (PhpStorm)
            - pkgs.jetbrains.clion (CLion)
            - pkgs.jetbrains.datagrip (DataGrip)
            - pkgs.jetbrains.dataspell (DataSpell)
            - pkgs.jetbrains.goland (GoLand)
            - pkgs.jetbrains.rider (Rider)
            - pkgs.jetbrains.rust-rover (RustRover)
          '';
          example = lib.literalExpression ''
            with pkgs; [
              jetbrains.idea-ultimate
              jetbrains.dataspell
            ]
          '';
        };
      };

      config = mkIf cfg.enable {
        home.packages = cfg.ides;
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ jetbrainsHomeModule ];
    }

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            # IDE settings and configurations
            ".config/JetBrains"
            # IDE caches
            ".cache/JetBrains"
            # IDE local data (recent projects, etc.)
            ".local/share/JetBrains"
          ];
        }) enabledUsers;
      };
    })
  ];
}
