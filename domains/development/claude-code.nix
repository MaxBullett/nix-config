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

  # Collect all users with Claude Code enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.development.claude-code.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
  claudeCodeHomeModule =
    { config, ... }:
    let
      cfg = config.domains.development.claude-code;
    in
    {
      options.domains.development.claude-code = {
        enable = mkEnableOption "Claude Code CLI interface";

        package = mkOption {
          type = types.package;
          default = pkgs.claude-code;
          defaultText = lib.literalExpression "pkgs.claude-code";
          description = ''
            The Claude Code package to use.

            Override this to use a different version or custom build.
          '';
        };
      };

      config = mkIf cfg.enable {
        home.packages = [ cfg.package ];
      };
    };
in
{
  config = mkMerge [
    # Inject the Claude Code home-manager module into all users
    {
      home-manager.sharedModules = [ claudeCodeHomeModule ];
    }

    # System-level configuration when any user has Claude Code enabled
    (mkIf anyEnabled {
      # Ensure Claude Code is available system-wide
      environment.systemPackages = [ pkgs.claude-code ];
    })

    # Conditional persistence for all enabled users
    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            # Claude Code configuration and state
            # Includes session history, settings, and cached data
            ".claude"
          ];
        }) enabledUsers;
      };
    })
  ];
}
