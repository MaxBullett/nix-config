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

  thinkrailPackage = pkgs.callPackage ./package.nix { };

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.development.thinkrail.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  thinkrailHomeModule =
    { config, ... }:
    let
      cfg = config.domains.development.thinkrail;
    in
    {
      options.domains.development.thinkrail = {
        enable = mkEnableOption "ThinkRail worktree IDE host for the pi coding agent";

        package = mkOption {
          type = types.package;
          default = thinkrailPackage;
          defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
          description = ''
            The ThinkRail package to use.
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
    {
      home-manager.sharedModules = [ thinkrailHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ thinkrailPackage ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist".users = mapAttrs (username: _: {
        directories = [
          # Primary app state: projects.json, workspaces.json, terminals.json,
          # config.json, installation.json (source: packages/server/src/persistence/persistence.ts)
          ".thinkrail"
          # The embedded `pi` coding agent's own home -- session/auth state and
          # extensions (source: packages/shared/src/jbcentral.ts writes
          # ~/.pi/agent/extensions/jetbrains-central.ts)
          ".pi"
          # Install metadata (install.json), written by apps/cli/src/paths.ts
          ".config/thinkrail"
        ];
      }) enabledUsers;
    })
  ];
}
