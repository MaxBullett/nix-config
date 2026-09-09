{
  config,
  inputs,
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

  inherit (pkgs.stdenv.hostPlatform) system;

  # Built against llm-agents.nix's own pinned nixpkgs, so the prebuilt binaries
  # from cache.numtide.com stay usable (see domains.nix.caches.extraCaches).
  claudeDesktopPackage = inputs.llm-agents.packages.${system}.claude-desktop;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.development.claude-desktop.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  claudeDesktopHomeModule =
    { config, ... }:
    let
      cfg = config.domains.development.claude-desktop;
    in
    {
      options.domains.development.claude-desktop = {
        enable = mkEnableOption "Claude Desktop application";

        package = mkOption {
          type = types.package;
          default = claudeDesktopPackage;
          defaultText =
            lib.literalExpression "inputs.llm-agents.packages.\${system}.claude-desktop";
          description = ''
            The Claude Desktop package to use.
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
      home-manager.sharedModules = [ claudeDesktopHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ claudeDesktopPackage ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist".users = mapAttrs (_username: _: {
        directories = [
          # Electron userData directory: MCP config (claude_desktop_config.json),
          # login session, window state and local caches.
          ".config/Claude"
        ];
      }) enabledUsers;
    })
  ];
}
