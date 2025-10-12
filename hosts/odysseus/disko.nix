{
  config,
  disk ? "/dev/nvme0n1",
  ...
}:
let
  defaultBtrfsOpts = [
    "compress=zstd:1"
    "discard=async"
    "noatime"
  ];
in
{
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                passwordFile = "/tmp/disko-password"; # this is populated by bootstrap-nixos.sh
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "lvm_pv";
                  vg = "vg0";
                };
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      vg0 = {
        type = "lvm_vg";
        lvs = {
          swap = {
            size = "40G";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = true;
            };
          };
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [
                "-fL"
                "root"
              ];
              postCreateHook = ''
                set -euo pipefail
                MNTPOINT=$(mktemp -d)
                mount -t btrfs "${config.fileSystems."/".device}" "$MNTPOINT"
                trap 'umount "$MNTPOINT"; rm -d "$MNTPOINT"' EXIT
                btrfs subvolume snapshot -r "$MNTPOINT"/@purge "$MNTPOINT"/@snapshots/purge-blank
              '';
              subvolumes = {
                "@purge" = {
                  mountpoint = "/";
                  mountOptions = defaultBtrfsOpts;
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = defaultBtrfsOpts;
                };
                "@preserve" = {
                  mountpoint = "/preserve";
                  mountOptions = defaultBtrfsOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = defaultBtrfsOpts;
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = defaultBtrfsOpts;
                };
              };
            };
          };
        };
      };
    };
  };
}
