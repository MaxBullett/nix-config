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

  # Collect all users with GitHub CLI enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.development.github-cli.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
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

          # Git credential helper integration
          gitCredentialHelper.enable = true;

          # Default settings
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
    # Inject the GitHub CLI home-manager module into all users
    {
      home-manager.sharedModules = [ githubCliHomeModule ];
    }

    # System-level configuration when any user has GitHub CLI enabled
    (mkIf anyEnabled {
      # Ensure gh is available system-wide
      environment.systemPackages = [ pkgs.gh ];
    })

    # Conditional persistence for all enabled users
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
