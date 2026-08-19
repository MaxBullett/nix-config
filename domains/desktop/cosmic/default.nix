{
  config,
  l,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.domains.desktop.cosmic;

  normalUsers = l.getNormalUsers config;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;
in
{
  options.domains.desktop.cosmic = {
    enable = mkEnableOption "COSMIC desktop environment";

    cosmic-greeter = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the COSMIC greeter (display manager).";
      };
    };

    xwayland = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable XWayland support for COSMIC.";
      };
    };

    autoLogin = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable auto login for the greeter.";
      };

      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Username to auto login as when autoLogin is enabled.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion =
            !(cfg.enable && cfg.autoLogin.enable) || (cfg.autoLogin.user != null && cfg.autoLogin.user != "");
          message = "domains.desktop.cosmic.autoLogin.user must be set when autoLogin.enable = true.";
        }
      ];

      nixpkgs.overlays = [
        (final: prev: {
          cosmic-comp = prev.cosmic-comp.overrideAttrs (oldAttrs: {
            # Concat list of patches here
            patches = (oldAttrs.patches or [ ]) ++ [
              ./no_ssd.patch # https://github.com/pop-os/cosmic-comp/issues/376
              ./cosmic_smart_gaps.patch # https://github.com/pop-os/cosmic-comp/issues/723
              ./cosmic-comp-idle-notify-activity.patch # https://github.com/pop-os/cosmic-greeter/issues/19
            ];
          });
        })
      ];

      services = {
        displayManager = {
          inherit (cfg) cosmic-greeter;

          autoLogin = mkIf cfg.autoLogin.enable {
            enable = true;
            inherit (cfg.autoLogin) user;
          };
        };

        desktopManager.cosmic = {
          enable = true;
          inherit (cfg) xwayland;
        };

        # Using system76's scheduler greatly improves performance of cosmic.
        system76-scheduler.enable = true;

        # Force gnome-keyring usage to solve various keyring issues
        gnome.gnome-keyring.enable = true;
      };

      security.pam.services.cosmic-greeter.enableGnomeKeyring = true;

      environment.sessionVariables = {
        # Fix clipboard issues in COSMIC
        COSMIC_DATA_CONTROL_ENABLED = 1;

        # Wayland Environment Fixes
        NIXOS_OZONE_WL = "1"; # Electron
        SDL_VIDEODRIVER = "wayland"; # Steam
        COSMIC_DISABLE_DIRECT_SCANOUT = "true"; # Fullscreen issues
      };

      environment.systemPackages = with pkgs; [
        cosmic-monitor
        ffmpegthumbnailer
        wl-clipboard
      ];
    })

    # Conditional persistence for all normal users
    (mkIf (cfg.enable && preservationEnabled) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            # COSMIC desktop settings and state
            ".config/cosmic"
            ".local/state/cosmic"
            ".local/state/cosmic-comp"

            # Initial setup flag
            ".config/cosmic-initial-setup-done"

            # Pop Launcher (app launcher) history and preferences
            ".local/state/pop-launcher"

            # Included keyring state
            ".local/share/keyrings"
          ];
        }) normalUsers;
      };
    })
  ];
}
