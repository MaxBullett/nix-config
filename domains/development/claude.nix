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
    optionals
    types
    ;

  inherit (pkgs.stdenv.hostPlatform) system;

  # Not in nixpkgs; built by llm-agents.nix against its own pinned nixpkgs, so
  # the prebuilt binaries from cache.numtide.com stay usable.
  claudeDesktopPackage = inputs.llm-agents.packages.${system}.claude-desktop;

  codeEnabled = userCfg: userCfg.domains.development.claude.code.enable or false;
  desktopEnabled = userCfg: userCfg.domains.development.claude.desktop.enable or false;

  codeUsers = filterAttrs (_: codeEnabled) config.home-manager.users;
  desktopUsers = filterAttrs (_: desktopEnabled) config.home-manager.users;
  enabledUsers = codeUsers // desktopUsers;

  anyEnabled = enabledUsers != { };

  claudeHomeModule =
    { config, ... }:
    let
      cfg = config.domains.development.claude;

      selectedPackages = lib.flatten [
        (lib.optional cfg.code.enable cfg.code.package)
        (lib.optional cfg.desktop.enable cfg.desktop.package)
      ];
    in
    {
      options.domains.development.claude = {
        code = {
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

        desktop = {
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
      };

      config = mkIf (cfg.code.enable || cfg.desktop.enable) {
        home.packages = selectedPackages;
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ claudeHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = lib.flatten [
        (lib.optional (codeUsers != { }) pkgs.claude-code)
        (lib.optional (desktopUsers != { }) claudeDesktopPackage)
      ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist".users = mapAttrs (_: userCfg: {
        directories = optionals (codeEnabled userCfg) [
          # Claude Code configuration and state
          ".claude"
        ]
        ++ optionals (desktopEnabled userCfg) [
          # Electron userData directory: MCP config (claude_desktop_config.json),
          # login session, window state and local caches
          ".config/Claude"
        ];
        files = optionals (codeEnabled userCfg) [
          # Claude Code global config (auth, onboarding state, project list)
          ".claude.json"
        ];
      }) enabledUsers;
    })
  ];
}
