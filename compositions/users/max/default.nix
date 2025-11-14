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

    users.users.${userName} = {
      isNormalUser = true;
      extraGroups = lib.flatten [
        "wheel"
        (lib.optional (config.networking.networkmanager.enable or false) "networkmanager")
        (lib.optional (config.virtualisation.docker.enable or false) "docker")
      ];
      hashedPasswordFile = config.sops.secrets."${secretKey}".path;
    };

    home-manager.users.${userName} = {
      domains = {
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

        editors.helix.enable = true;

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
          claude-code.enable = true;
          jetbrains = {
            dataspell.enable = true;
            ideaUltimate.enable = true;
          };
        };

        tools = {
          yazi.enable = true;
          ripgrep.enable = true;
        };

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

        applications = {
          firefox.enable = true;
          steam = {
            enable = true;
            extraCompatPackages = with pkgs; [ proton-ge-bin ];
          };
          obs-studio = {
            enable = true;
            enableVirtualCamera = true;
          };
          flatpak = {
            enable = true;
            betaPackages = [ "com.stremio.Stremio" ];
          };
        };
      };

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
