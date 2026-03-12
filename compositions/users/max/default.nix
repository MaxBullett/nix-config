{
  config,
  inputs,
  lib,
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
      "ssh/work-config" = {
        sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
        mode = "0600";
        owner = userName;
      };
      "atuin/key" = {
        sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
        mode = "0600";
        owner = userName;
      };
      "atuin/session" = {
        sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
        mode = "0600";
        owner = userName;
      };
    };

    users.users.${userName} = {
      isNormalUser = true;
      extraGroups = lib.flatten [
        "wheel"
        (lib.optional (config.networking.networkmanager.enable or false) "networkmanager")
        (lib.optional (config.virtualisation.docker.enable or false) "docker")
        (lib.optional (config.hardware.sane.enable or false) "scanner")
      ];
      hashedPasswordFile = config.sops.secrets."${secretKey}".path;
    };

    home-manager.users.${userName} = {
      domains = {
        shell = {
          nushell = {
            enable = true;
            shellAliases = {
              doco = "docker compose";
              jc = "journalctl";
              sc = "systemctl";
            };
          };
          starship.enable = true;
          atuin = {
            enable = true;
            sync = {
              enable = true;
              keyFile = config.sops.secrets."atuin/key".path;
              sessionFile = config.sops.secrets."atuin/session".path;
            };
          };
          carapace.enable = true;
          zoxide.enable = true;
        };

        editors.helix.enable = true;

        security = {
          ssh = {
            enable = true;
            extraConfig = ''
              Include ${config.sops.secrets."ssh/work-config".path}
            '';
            matchBlocks = {
              "github.com" = {
                identityFile = "~/.ssh/id_ed25519";
                identitiesOnly = true;
              };
              "10.10.10.101" = {
                user = "root";
                identityFile = "~/.ssh/id_ed25519";
                identitiesOnly = true;
              };
            };
          };
        };

        development = {
          direnv.enable = true;
          git = {
            enable = true;
            settings = {
              user = {
                name = "MaxBullett";
                email = "31956266+MaxBullett@users.noreply.github.com";
              };
            };
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
          python.enable = true;
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
          vivaldi.enable = true;
          obs-studio = {
            enable = true;
            enableVirtualCamera = true;
          };
          flatpak = {
            enable = true;
            betaPackages = [ "com.stremio.Stremio" ];
          };
          figma-linux.enable = true;
          proton-pass.enable = true;
        };
      };

      home = {
        username = userName;
        homeDirectory = "/home/${userName}";
        stateVersion = "25.05";
      };
    };
  }

  # Custom directory persistence (non-XDG directories)
  (mkIf (config.domains.storage.btrfs.preservation.enable or false) {
    domains.storage.btrfs.preservation.mounts = {
      "/persist".users.${userName} = {
        directories = [
          {
            directory = "code";
            how = "symlink";
          }
          ".local/share/fonts"
        ];
        files = [ ];
      };
      "/preserve".users.${userName} = {
        directories = [
          {
            directory = "work";
            how = "symlink";
          }
        ];
        files = [ ];
      };
    };
  })
]
