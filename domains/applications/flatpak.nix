{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    flatten
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    unique
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.applications.flatpak.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  allPackages =
    let
      userPackageLists = lib.mapAttrsToList (
        _: userCfg: userCfg.domains.applications.flatpak.packages or [ ]
      ) enabledUsers;
    in
    unique (flatten userPackageLists);

  allBetaPackages =
    let
      userPackageLists = lib.mapAttrsToList (
        _: userCfg: userCfg.domains.applications.flatpak.betaPackages or [ ]
      ) enabledUsers;
    in
    unique (flatten userPackageLists);

  flatpakHomeModule = {
    options.domains.applications.flatpak = {
      enable = mkEnableOption "Flatpak application management";

      packages = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of Flatpak packages to install from Flathub.
          Specify just the app ID (e.g., "org.mozilla.firefox").
        '';
        example = lib.literalExpression ''
          [
            "org.mozilla.firefox"
            "com.spotify.Client"
          ]
        '';
      };

      betaPackages = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of Flatpak packages to install from Flathub Beta.
          Specify just the app ID (e.g., "com.stremio.Stremio").
        '';
        example = lib.literalExpression ''
          [
            "com.stremio.Stremio"
          ]
        '';
      };
    };
  };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ flatpakHomeModule ];
    }

    (mkIf anyEnabled {
      services.flatpak.enable = true;

      systemd.services.flatpak-managed-install = {
        description = "Install declarative Flatpak packages";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script =
          let
            flatpak = "${config.services.flatpak.package}/bin/flatpak";
          in
          ''
            # Add flathub remote
            ${flatpak} remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

            ${lib.optionalString (allBetaPackages != [ ]) ''
              # Add flathub-beta remote
              ${flatpak} remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
            ''}

            # Install packages from flathub
            ${lib.concatMapStringsSep "\n" (pkg: ''
              ${flatpak} install --system --noninteractive flathub ${pkg} || true
            '') allPackages}

            # Install packages from flathub-beta
            ${lib.concatMapStringsSep "\n" (pkg: ''
              ${flatpak} install --system --noninteractive flathub-beta ${pkg} || true
            '') allBetaPackages}
          '';
      };
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts = {
        "/persist".directories = [ "/var/lib/flatpak" ];

        "/persist".users = mapAttrs (username: _: {
          directories = [
            # User flatpak installations
            ".local/share/flatpak"
            # Flatpak app data and state
            ".var/app"
          ];
        }) enabledUsers;
      };
    })
  ];
}
