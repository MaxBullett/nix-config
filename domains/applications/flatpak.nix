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

  # Transform pinned bundle definitions into nix-flatpak's `bundle` package format.
  # `sha256` is required: nix-flatpak only (re)installs a bundle when it differs
  # between the previous and new state, so a null value means it never installs.
  transformBundles =
    pkgs: bundles:
    map (bundle: {
      inherit (bundle) appId;
      sha256 = bundle.hash;
      bundle = "${pkgs.fetchurl { inherit (bundle) url hash; }}";
    }) bundles;

  bundleType = types.submodule {
    options = {
      appId = mkOption {
        type = types.str;
        description = "The fully qualified app ID of the Flatpak bundle.";
        example = "com.nuvio.media.desktop";
      };

      url = mkOption {
        type = types.str;
        description = "Download URL of the .flatpak bundle file.";
      };

      hash = mkOption {
        type = types.str;
        description = ''
          SRI hash of the bundle file (e.g. obtained via `nix-prefetch-url --type sha256 <url>`
          piped through `nix hash convert --hash-algo sha256 --to sri`).
        '';
        example = "sha256-8h1O4gFPakoUUWCNgzf8WmkfiQAYlCtSG2FSxt7gxoU=";
      };
    };
  };

  flatpakHomeModule =
    { config, pkgs, ... }:
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

        bundlePackages = mkOption {
          type = with types; listOf bundleType;
          default = [ ];
          description = ''
            Flatpak applications installed from a pinned bundle URL rather than a
            Flathub remote (e.g. apps that only publish a standalone .flatpak on
            GitHub releases). Unlike `packages`/`betaPackages`, updates are not
            automatic on activation - bump `url`/`hash` to a newer release when
            you want one. The app's runtime/SDK still resolves against the
            configured remotes (Flathub), so it must be published there.
          '';
          example = lib.literalExpression ''
            [
              {
                appId = "com.nuvio.media.desktop";
                url = "https://github.com/NuvioMedia/NuvioDesktop/releases/download/0.1.24-alpha/Nuvio-Linux-x86_64-0.1.24-alpha.flatpak";
                hash = "sha256-8h1O4gFPakoUUWCNgzf8WmkfiQAYlCtSG2FSxt7gxoU=";
              }
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
            ++ transformPackages config.domains.applications.flatpak.betaPackages "flathub-beta"
            ++ transformBundles pkgs config.domains.applications.flatpak.bundlePackages;

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
