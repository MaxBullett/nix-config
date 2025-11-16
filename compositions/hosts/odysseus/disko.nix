{
  config,
  ...
}:
{
  disko.devices = {
    disk.nvme0n1 = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-eui.000000000000000100a075213332eac0";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512MiB";
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
              content = {
                type = "lvm_pv";
                vg = "vg0";
              };
            };
          };
        };
      };
    };

    lvm_vg.vg0 = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = "40G";
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };
        root = {
          size = "100%FREE";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
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
                mountOptions = [
                  "compress=zstd:1"
                  "discard=async"
                  "noatime"
                ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd:1"
                  "discard=async"
                  "noatime"
                ];
              };
              "@persist" = {
                mountpoint = "/persist";
                mountOptions = [
                  "compress=zstd:1"
                  "discard=async"
                  "noatime"
                ];
              };
              "@preserve" = {
                mountpoint = "/preserve";
                mountOptions = [
                  "compress=zstd:1"
                  "discard=async"
                  "noatime"
                ];
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [
                  "compress=zstd:1"
                  "discard=async"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
