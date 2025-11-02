{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkMerge;
  userName = "max";
  secretKey = "passwords/${userName}";
in
mkMerge [
  {
    # SOPS secrets for this user
    sops = {
      secrets."${secretKey}" = {
        sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
        neededForUsers = true;
      };
    };

    # System-level user configuration
    users.users.${userName} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ]
      # Conditionally add docker group if docker is enabled
      ++ lib.optional (config.virtualisation.docker.enable or false) "docker";
      hashedPasswordFile = config.sops.secrets."${secretKey}".path;
    };

    # Home Manager configuration
    home-manager.users.${userName} = {
      # Domain configuration
      domains = {
        # Shell configuration
        shell = {
          nushell = {
            enable = true;
            shellAliases = {
              ll = "ls -l";
              la = "ls -la";
              ".." = "cd ..";
              "..." = "cd ../..";
            };
          };
          starship.enable = true;
          zoxide.enable = true;
          atuin.enable = true;
          carapace.enable = true;
        };

        # Editor configuration
        editors.helix = {
          enable = true;
          theme = "catppuccin_macchiato";
        };

        # Development tools
        development.direnv.enable = true;

        # CLI tools
        tools.yazi.enable = true;

        # Desktop configuration
        desktop.xdg = {
          enable = true;

          # Ephemeral - persisted on /persist
          desktop = {
            path = "desktop";
            mountPoint = "/persist";
          };
          download = {
            path = "downloads";
            mountPoint = "/persist";
          };
          publicShare = {
            path = "public";
            mountPoint = "/persist";
          };
          templates = {
            path = "templates";
            mountPoint = "/persist";
          };

          # Important data - persisted on /preserve (snapshotted)
          documents = {
            path = "documents";
            mountPoint = "/preserve";
          };
          music = {
            path = "music";
            mountPoint = "/preserve";
          };
          pictures = {
            path = "pictures";
            mountPoint = "/preserve";
          };
          videos = {
            path = "videos";
            mountPoint = "/preserve";
          };
        };

        # Applications
        applications.firefox.enable = true;
      };

      # Home configuration
      home = {
        username = userName;
        homeDirectory = "/home/${userName}";
        packages = with pkgs; [
          htop
          jq
        ];
        stateVersion = "25.05";
      };

      # Git configuration
      programs.git.enable = true;
    };
  }

  # Custom directory persistence (non-XDG directories)
  (mkIf (config.domains.storage.btrfs.preservation.enable or false) {
    domains.storage.btrfs.preservation.mounts = {
      "/persist".users.${userName} = {
        directories = [
          "code"
        ];
        files = [ ];
      };
      "/preserve".users.${userName} = {
        directories = [
          "work"
        ];
        files = [ ];
      };
    };
  })
]
