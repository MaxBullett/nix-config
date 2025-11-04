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
    sops.secrets = {
      "${secretKey}" = {
        sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
        neededForUsers = true;
      };
      "ssh/id_ed25519/private" = {
        sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
        path = "/home/${userName}/.ssh/id_ed25519";
        mode = "0600";
        owner = userName;
      };
      "ssh/id_ed25519/public" = {
        sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
        path = "/home/${userName}/.ssh/id_ed25519.pub";
        mode = "0644";
        owner = userName;
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
        development = {
          direnv.enable = true;
          git = {
            enable = true;
            userName = "MaxBullett";
            userEmail = "31956266+MaxBullett@users.noreply.github.com";
            signing = {
              enable = true;
              key = "~/.ssh/id_ed25519.pub";
            };
          };
          github-cli.enable = true;
        };

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
