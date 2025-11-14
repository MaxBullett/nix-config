{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mkEnableOption
    mkIf
    mkMerge
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.tools.ripgrep.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  ripgrepHomeModule =
    { config, ... }:
    let
      cfg = config.domains.tools.ripgrep;
    in
    {
      options.domains.tools.ripgrep = {
        enable = mkEnableOption "ripgrep - fast line-oriented search tool";
      };

      config = mkIf cfg.enable {
        home.packages = [ pkgs.ripgrep ];
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ ripgrepHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.ripgrep ];
    })
  ];
}
