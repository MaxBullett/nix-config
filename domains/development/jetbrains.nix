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
    ;

  enabledUsers = filterAttrs (
    _: userCfg:
    let
      jb = userCfg.domains.development.jetbrains or { };
    in
    (jb.dataspell.enable or false) || (jb.ideaUltimate.enable or false)
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

      selectedIDEs = lib.flatten [
        (lib.optional cfg.dataspell.enable pkgs.jetbrains.dataspell)
        (lib.optional cfg.ideaUltimate.enable pkgs.jetbrains.idea-ultimate)
      ];
    in
    {
      options.domains.development.jetbrains = {
        dataspell = {
          enable = mkEnableOption "DataSpell (Python data science IDE)";
        };

        ideaUltimate = {
          enable = mkEnableOption "IntelliJ IDEA Ultimate";
        };
      };

      config = mkIf (cfg.dataspell.enable || cfg.ideaUltimate.enable) {
        home.packages = selectedIDEs;
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
