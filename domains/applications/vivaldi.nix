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
    _: userCfg: userCfg.domains.applications.vivaldi.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home module only declares the enable option — Vivaldi has no HM module and
  # is configured entirely through its own UI (settings are persisted in the profile).
  vivaldiHomeModule = {
    options.domains.applications.vivaldi = {
      enable = mkEnableOption "Vivaldi web browser";
    };
  };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ vivaldiHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.vivaldi ];

      # Vivaldi uses GTK for native OS elements (file dialogs, etc.);
      # Stylix's GTK theme applies automatically without explicit integration.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (_: _: {
          directories = [
            ".config/vivaldi"
            ".cache/vivaldi"
            ".local/lib/vivaldi"
          ];
        }) enabledUsers;
      };
    })
  ];
}
