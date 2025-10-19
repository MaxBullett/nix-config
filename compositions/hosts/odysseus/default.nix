{
  config,
  l,
  hostName ? "odysseus",
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
  };

  networking.hostName = hostName;
  time.timeZone = "Europe/Berlin";

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
  };

  domains = {
    security.sops = {
      enable = true;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
    boot.systemd-boot.enable = true;
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
              "/etc/ssh"
              {
                directory = "/var/lib/nixos";
                inInitrd = true;
              }
              {
                directory = "/var/lib/private";
                mode = "0700";
              }
              "/var/lib/systemd"
              "/var/log"
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
    };
  };

  system.stateVersion = "25.05";
}
