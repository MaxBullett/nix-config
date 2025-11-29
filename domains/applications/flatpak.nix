{
  config,
  inputs,
  lib,
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
    _: userCfg: userCfg.domains.applications.flatpak.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Transform user packages into nix-flatpak format
  transformPackages =
    packages: origin:
    map (appId: {
      inherit appId origin;
    }) packages;

  flatpakHomeModule =
    { config, ... }:
    {
      imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

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

      config = mkIf config.domains.applications.flatpak.enable {
        services.flatpak = {
          enable = true;

          # Configure remotes
          remotes = [
            {
              name = "flathub";
              location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
            }
          ]
          ++ lib.optional (config.domains.applications.flatpak.betaPackages != [ ]) {
            name = "flathub-beta";
            location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
          };

          # Transform packages into nix-flatpak format
          packages =
            transformPackages config.domains.applications.flatpak.packages "flathub"
            ++ transformPackages config.domains.applications.flatpak.betaPackages "flathub-beta";

          # Update on activation for fresh installs
          update.onActivation = true;
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
      # Enable system flatpak service
      services.flatpak.enable = true;
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
