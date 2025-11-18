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

      # Patch cosmic-session to use correct gcr-ssh-agent socket path
      # Upstream issue: https://github.com/pop-os/cosmic-session/issues/148
      nixpkgs.overlays = [
        (final: prev: {
          cosmic-session = prev.cosmic-session.overrideAttrs (oldAttrs: {
            postPatch = (oldAttrs.postPatch or "") + ''
              substituteInPlace data/start-cosmic \
                --replace-fail '/keyring/ssh' '/gcr/ssh'
            '';
          });
        })
      ];

      services.displayManager = {
        inherit (cfg) cosmic-greeter;

        autoLogin = mkIf cfg.autoLogin.enable {
          enable = true;
          inherit (cfg.autoLogin) user;
        };
      };

      services.desktopManager.cosmic = {
        enable = true;
        inherit (cfg) xwayland;
      };

      environment.sessionVariables = {
        # Fix clipboard issues in COSMIC
        COSMIC_DATA_CONTROL_ENABLED = 1;

        # Wayland Environment Fixes
        NIXOS_OZONE_WL = "1"; # Electron
        SDL_VIDEODRIVER = "wayland"; # Steam
        COSMIC_DISABLE_DIRECT_SCANOUT = "true"; # Fullscreen issues
      };

      environment.systemPackages = with pkgs; [
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
          ];
        }) normalUsers;
      };
    })
  ];
}
