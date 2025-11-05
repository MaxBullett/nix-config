{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.domains.storage.btrfs.snapshots;
in
{
  options.domains.storage.btrfs.snapshots = {
    enable = mkEnableOption "periodic snapshots and remote backups of btrfs subvolumes";

    subvolume = mkOption {
      type = types.str;
      description = ''
        Path to the subvolume to snapshot.
        Should be a btrfs subvolume mount point.
      '';
      example = "/preserve";
    };

    snapshotPath = mkOption {
      type = types.str;
      description = ''
        Directory where snapshots will be stored.
        Must be on the same btrfs filesystem as the subvolume.
      '';
      example = "/.snapshots/preserve";
    };

    local = {
      retention = {
        daily = mkOption {
          type = types.int;
          default = 7;
          description = "Number of daily snapshots to keep locally";
        };

        weekly = mkOption {
          type = types.int;
          default = 4;
          description = "Number of weekly snapshots to keep locally";
        };

        monthly = mkOption {
          type = types.int;
          default = 0;
          description = "Number of monthly snapshots to keep locally";
        };

        yearly = mkOption {
          type = types.int;
          default = 0;
          description = "Number of yearly snapshots to keep locally";
        };
      };
    };

    remote = {
      enable = mkEnableOption "remote backup to cloud storage via restic";

      repository = mkOption {
        type = types.str;
        example = "b2:bucket-name:/backups";
        description = ''
          Restic repository URL.
          For Backblaze B2: b2:bucket-name:/path
        '';
      };

      passwordFile = mkOption {
        type = types.path;
        example = "/run/secrets/restic-password";
        description = ''
          Path to file containing restic repository password.
          Should be provided via sops-nix or similar secret management.
        '';
      };

      b2KeyId = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/b2/keyID";
        description = ''
          Path to file containing Backblaze B2 key ID.
          Required when using b2: repository.
        '';
      };

      b2ApplicationKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/b2/applicationKey";
        description = ''
          Path to file containing Backblaze B2 application key.
          Required when using b2: repository.
        '';
      };

      retention = {
        daily = mkOption {
          type = types.int;
          default = 7;
          description = "Number of daily backups to keep remotely";
        };

        weekly = mkOption {
          type = types.int;
          default = 4;
          description = "Number of weekly backups to keep remotely";
        };

        monthly = mkOption {
          type = types.int;
          default = 12;
          description = "Number of monthly backups to keep remotely";
        };

        yearly = mkOption {
          type = types.int;
          default = 1;
          description = "Number of yearly backups to keep remotely";
        };
      };

      schedule = mkOption {
        type = types.str;
        default = "daily";
        description = "When to run backups (systemd timer format)";
        example = "02:00";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.subvolume != "";
        message = "domains.storage.btrfs.snapshots.subvolume must be set";
      }
      {
        assertion = cfg.snapshotPath != "";
        message = "domains.storage.btrfs.snapshots.snapshotPath must be set";
      }
      {
        assertion = cfg.remote.enable -> cfg.remote.repository != "";
        message = "domains.storage.btrfs.snapshots.remote.repository must be set when remote backups are enabled";
      }
      {
        assertion = cfg.remote.enable -> cfg.remote.passwordFile != null;
        message = "domains.storage.btrfs.snapshots.remote.passwordFile must be set when remote backups are enabled";
      }
    ];

    # Install btrbk
    environment.systemPackages = [ pkgs.btrbk ];

    # Ensure snapshot directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.snapshotPath} 0755 root root -"
    ];

    # btrbk configuration
    environment.etc."btrbk/btrbk.conf".text =
      let
        inherit (cfg.local) retention;
        retentionSpec = "${toString retention.daily}d ${toString retention.weekly}w ${toString retention.monthly}m ${toString retention.yearly}y";
      in
      ''
        # btrbk configuration for ${cfg.subvolume}
        timestamp_format long
        snapshot_preserve_min latest
        snapshot_preserve ${retentionSpec}

        volume ${cfg.subvolume}
          snapshot_dir ${cfg.snapshotPath}
          subvolume .
      '';

    # Systemd configuration for btrbk and restic
    systemd = {
      # Systemd service for btrbk
      services.btrbk-snapshot = {
        description = "Create btrfs snapshots with btrbk";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.btrbk}/bin/btrbk -c /etc/btrbk/btrbk.conf run";
        };
      };

      # Systemd timer for btrbk (runs daily at 01:00)
      timers.btrbk-snapshot = {
        description = "Daily btrfs snapshot timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };

      # Ensure restic backup runs after btrbk snapshot
      services.restic-backups-preserve = mkIf cfg.remote.enable {
        after = [ "btrbk-snapshot.service" ];
        wants = [ "btrbk-snapshot.service" ];
      };
    };

    # Restic remote backup configuration
    services.restic.backups = mkIf cfg.remote.enable {
      preserve = {
        inherit (cfg.remote) repository passwordFile;

        # Backup from the latest snapshot
        paths = [ "${cfg.snapshotPath}" ];

        # Run after btrbk creates snapshots
        timerConfig = {
          OnCalendar = cfg.remote.schedule;
          Persistent = true;
        };

        # Prune old backups according to retention policy
        pruneOpts =
          let
            inherit (cfg.remote) retention;
          in
          [
            "--keep-daily ${toString retention.daily}"
            "--keep-weekly ${toString retention.weekly}"
            "--keep-monthly ${toString retention.monthly}"
            "--keep-yearly ${toString retention.yearly}"
          ];

        # B2 credentials
        backupPrepareCommand = mkIf (cfg.remote.b2KeyId != null && cfg.remote.b2ApplicationKey != null) ''
          export B2_ACCOUNT_ID="$(cat ${cfg.remote.b2KeyId})"
          export B2_ACCOUNT_KEY="$(cat ${cfg.remote.b2ApplicationKey})"
        '';

        # Additional options
        extraBackupArgs = [
          "--exclude-caches"
          "--one-file-system"
        ];
      };
    };
  };
}
