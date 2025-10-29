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

  # Collect all users with yazi enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.tools.yazi.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
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
          poppler_utils # PDF preview
          fd # File searching
          ripgrep # Content searching
          fzf # Fuzzy finding
        ];
      };
    };
in
{
  config = mkMerge [
    # Inject the yazi home-manager module into all users
    {
      home-manager.sharedModules = [ yaziHomeModule ];
    }

    # System-level configuration when any user has yazi enabled
    (mkIf anyEnabled {
      # Ensure yazi is available system-wide
      environment.systemPackages = [ pkgs.yazi ];
    })

    # Conditional persistence for all enabled users
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
