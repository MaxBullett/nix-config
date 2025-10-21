{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  btrfs_cfg = config.domains.storage.btrfs;
  cfg = btrfs_cfg.preservation;

  userBlueprintType = types.submodule {
    options = {
      directories = mkOption {
        type = with types; listOf (either str attrs);
        default = [ ];
        description = "Relative directories under the user home to persist.";
      };
      files = mkOption {
        type = with types; listOf (either str attrs);
        default = [ ];
        description = "Relative files under the user home to persist.";
      };
    };
  };

  mountBlueprintType = types.submodule (
    { name, ... }:
    {
      options = {
        neededForBoot = mkOption {
          type = types.bool;
          default = true;
          description = "Whether this persistent mount must be available during boot.";
        };

        persistentStoragePath = mkOption {
          type = types.str;
          default = name;
          description = "Path on the persistent volume where state is stored.";
        };

        directories = mkOption {
          type = with types; listOf (either str attrs);
          default = [ ];
          description = "Absolute directories to preserve on this mount.";
        };

        files = mkOption {
          type = with types; listOf (either str attrs);
          default = [ ];
          description = "Absolute files to preserve on this mount.";
        };

        users = mkOption {
          type = types.attrsOf userBlueprintType;
          default = { };
          description = "Per-user persistence definitions under this mount.";
        };
      };
    }
  );

  mountBlueprint =
    mountCfg:
    lib.filterAttrs (_: v: v != [ ] && v != { }) {
      inherit (mountCfg) persistentStoragePath directories files;
      users = mapAttrs (_: userCfg: {
        inherit (userCfg) directories files;
      }) mountCfg.users;
    };

  preserveAtBlueprints = mapAttrs (_: mountBlueprint) cfg.mounts;
  fileSystemDefinitions = mapAttrs (_: mountCfg: {
    inherit (mountCfg) neededForBoot;
  }) cfg.mounts;
in
{
  imports = [ inputs.preservation.nixosModules.default ];

  options.domains.storage.btrfs.preservation = {
    enable = mkEnableOption "Ephemeral-state management using preservation.";

    rootDevice = mkOption {
      type = types.str;
      default = config.fileSystems."/".device;
      defaultText = lib.literalExpression ''config.fileSystems."/".device'';
      description = "Device containing the btrfs filesystem (typically the root filesystem device).";
    };

    rootSubvolume = mkOption {
      type = types.str;
      default = "@purge";
      description = "Name of the ephemeral root subvolume to purge and restore.";
    };

    blankSnapshot = mkOption {
      type = types.str;
      default = "@snapshots/purge-blank";
      description = "Path to the blank snapshot used for restoration.";
    };

    emergencyAccess = mkOption {
      type = types.bool;
      default = true;
      description = "Enable emergency access during initrd if root purge fails.";
    };

    mounts = mkOption {
      type = types.attrsOf mountBlueprintType;
      default = { };
      description = ''
        Map of persistent mount points to their preservation blueprint.
        Each entry is forwarded to preservation.preserveAt and marked as boot-critical
        when requested.
      '';
    };
  };

  config = mkIf (btrfs_cfg.enable && cfg.enable) {
    assertions = [
      {
        assertion = btrfs_cfg.enable;
        message = "domains.storage.btrfs.preservation requires domains.storage.btrfs.enable = true";
      }
      {
        assertion = cfg.rootDevice != "";
        message = "domains.storage.btrfs.preservation.rootDevice must be set";
      }
      {
        assertion = cfg.rootSubvolume != "";
        message = "domains.storage.btrfs.preservation.rootSubvolume must be set";
      }
      {
        assertion = cfg.blankSnapshot != "";
        message = "domains.storage.btrfs.preservation.blankSnapshot must be set";
      }
    ];

    # Configure preservation
    preservation = {
      enable = mkDefault true;
      preserveAt = preserveAtBlueprints;
    };

    fileSystems = fileSystemDefinitions;

    # Configure root purge service
    boot.initrd.systemd = {
      inherit (cfg) emergencyAccess;

      services.purge-root = {
        description = "Purge and restore root subvolume from blank snapshot";
        wantedBy = [ "initrd.target" ];
        before = [ "sysroot.mount" ];
        requires = [ "initrd-root-device.target" ];
        after = [ "initrd-root-device.target" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";

        path = with pkgs; [ btrfs-progs ];

        script = ''
          set -euo pipefail
          export PATH="$PATH:/bin"

          echo "Mounting btrfs root filesystem"
          MNTPOINT=$(mktemp -d)
          mount -o subvol=/ ${lib.escapeShellArg cfg.rootDevice} "$MNTPOINT"
          trap 'umount "$MNTPOINT"; rm -d "$MNTPOINT"' EXIT

          echo "Purging root subvolume: ${cfg.rootSubvolume}"
          btrfs subvolume delete -R "$MNTPOINT/${cfg.rootSubvolume}" || true

          echo "Restoring root from snapshot: ${cfg.blankSnapshot}"
          btrfs subvolume snapshot "$MNTPOINT/${cfg.blankSnapshot}" "$MNTPOINT/${cfg.rootSubvolume}"

          echo "Root subvolume restored successfully"
        '';
      };
    };
  };
}
