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
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.development.github-cli.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  githubCliHomeModule =
    { config, ... }:
    let
      cfg = config.domains.development.github-cli;
    in
    {
      options.domains.development.github-cli = {
        enable = mkEnableOption "GitHub CLI (gh)";
      };

      config = mkIf cfg.enable {
        programs.gh = {
          enable = true;
          gitCredentialHelper.enable = true;

          settings = {
            git_protocol = "ssh";
            prompt = "enabled";
          };
        };
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ githubCliHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.gh ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/preserve" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/gh"
          ];
        }) enabledUsers;
      };
    })
  ];
}
