{
  config,
  hostName ? "odysseus",
  l,
  pkgs,
  ...
}:
let
  hostUsers = [ "max" ];
in
{
  imports = l.usersForHost hostName hostUsers;

  sops.secrets = {
    "machine-id" = {
      mode = "0444";
    };
    "passwords/root" = {
      neededForUsers = true;
    };
    "cachix-token" = {
      mode = "0440";
      group = "nixbld";
    };
    "github-token" = {
      mode = "0400";
    };
    "ca-certs/daadev" = { };
    "restic" = {
      mode = "0400";
    };
    "b2/keyID" = {
      mode = "0400";
    };
    "b2/applicationKey" = {
      mode = "0400";
    };
  };

  networking.hostName = hostName;

  environment.etc.machine-id.source = "${config.sops.secrets."machine-id".path}";

  users = {
    mutableUsers = false;
    users.root = {
      hashedPasswordFile = config.sops.secrets."passwords/root".path;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "old";
    overwriteBackup = true;
  };

  domains = {
    system = {
      localization = {
        timeZone = "Europe/Berlin";
        defaultLocale = "en_IE.UTF-8";
        extraLocaleSettings = {
          LC_TIME = "en_DK.UTF-8";
        };
        keyboardLayout = "us";
      };
      time-sync.enable = true;
      zram.enable = true;
      journald.enable = true;
    };
    nix = {
      daemon = {
        builders-use-substitutes = true;
        download-buffer-size = 500 * 1024 * 1024; # 500MB
        githubTokenFile = config.sops.secrets."github-token".path;
      };
      nh = {
        enable = true;
        clean.enable = true;
      };
      nixpkgs.allowUnfree = true;
      caches = {
        extraCaches = [
          {
            url = "https://maxbullett.cachix.org";
            key = "maxbullett.cachix.org-1:/6uBIAw06/eUnFR/UTgTk4w9ZfSAtrf3a1R9aOkpixY=";
          }
        ];
        push = {
          enable = true;
          cacheName = "maxbullett";
          tokenFile = config.sops.secrets."cachix-token".path;
        };
      };
    };
    security = {
      sops = {
        enable = true;
        installCli = true;
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };
      pki = {
        enable = true;
        certificatePaths = [ config.sops.secrets."ca-certs/daadev".path ];
      };
      doas = {
        enable = true;
        allowPowerCommands = true;
      };
    };
    boot = {
      plymouth.enable = true;
      systemd-boot = {
        enable = true;
        kernel = "latest"; # Use latest stable kernel
      };
    };
    storage.btrfs = {
      enable = true;
      preservation = {
        enable = true;
        rootSubvolume = "@purge";
        blankSnapshot = "@snapshots/purge-blank";
        mounts = {
          "/nix".neededForBoot = true;
          "/persist" = {
            neededForBoot = true;
            directories = [
              "/etc/asusd"
              {
                directory = "/var/lib/nixos";
                inInitrd = true;
              }
              {
                directory = "/var/lib/private";
                mode = "0700";
              }
              "/var/lib/systemd"
            ];
            files = [
              {
                file = "/var/lib/logrotate.status";
                mode = "0600";
                how = "symlink";
              }
            ];
          };
          "/preserve" = {
            neededForBoot = true;
          };
        };
      };
      snapshots = {
        enable = true;
        subvolume = "/preserve";
        snapshotPath = "/.snapshots/preserve";
        remote = {
          enable = true;
          repository = "b2:odysseus-backup:/snapshots";
          passwordFile = config.sops.secrets."restic".path;
          b2KeyId = config.sops.secrets."b2/keyID".path;
          b2ApplicationKey = config.sops.secrets."b2/applicationKey".path;
        };
      };
    };
    networking = {
      networkmanager = {
        enable = true;
        wifi.backend = "iwd";
        networks = [ "acheron" ];
      };
      avahi.enable = true;
    };
    hardware = {
      power-profiles-daemon.enable = true;
      firmware.enable = true;
      sensors.enable = true;
    };
    peripherals.bluetooth = {
      enable = true;
      settings = {
        General.Experimental = true;
      };
    };
    audio.pipewire.enable = true;
    printing.cups.enable = true;
    desktop = {
      cosmic = {
        enable = true;
        cosmic-greeter.enable = true;
      };
      stylix = {
        enable = true;
        scheme = "catppuccin-macchiato";
        polarity = "dark";
        wallpaper = ./wallpaper.jpg;
      };
      cursors = {
        package = pkgs.catppuccin-cursors.macchiatoSky;
        name = "catppuccin-macchiato-sky-cursors";
        size = 24;
      };
    };
    applications.steam = {
      enable = true;
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
    };
    development = {
      ansible.enable = true;
      docker.enable = true;
    };
  };

  system.stateVersion = "25.05";
}
