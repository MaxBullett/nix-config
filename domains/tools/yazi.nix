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
    _: userCfg: userCfg.domains.tools.yazi.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  yaziHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.tools.yazi;
    in
    {
      options.domains.tools.yazi = {
        enable = mkEnableOption "yazi terminal file manager";

        wrapperName = mkOption {
          type = types.str;
          default = "y";
          description = "Name of the shell wrapper function for cd-on-quit.";
        };
      };

      config = mkIf cfg.enable {
        # Install yazi and useful optional dependencies
        home.packages = with pkgs; [
          yazi
          # Optional dependencies for better functionality
          ffmpegthumbnailer # Video thumbnails
          unar # Archive preview
          jq # JSON preview
          poppler-utils # PDF preview
          fd # File searching
          ripgrep # Content searching
          fzf # Fuzzy finding
        ];
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ yaziHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.yazi ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/yazi"
            ".local/state/yazi"
          ];
        }) enabledUsers;
      };
    })
  ];
}
