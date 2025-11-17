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
      {
        assertion =
          let
            isB2Repository = cfg.remote.enable && (lib.hasPrefix "b2:" cfg.remote.repository);
            hasB2Credentials = cfg.remote.b2KeyId != null && cfg.remote.b2ApplicationKey != null;
          in
          isB2Repository -> hasB2Credentials;
        message = "domains.storage.btrfs.snapshots.remote.b2KeyId and b2ApplicationKey must be set when using a B2 repository";
      }
    ];

    environment.systemPackages = [ pkgs.btrbk ];

    systemd.tmpfiles.rules = [
      "d ${cfg.snapshotPath} 0755 root root -"
    ];

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

    systemd = {
      services.btrbk-snapshot = {
        description = "Create btrfs snapshots with btrbk";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.btrbk}/bin/btrbk -c /etc/btrbk/btrbk.conf run";
        };
      };

      timers.btrbk-snapshot = {
        description = "Daily btrfs snapshot timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };

      services.restic-backups-preserve = mkIf cfg.remote.enable {
        after = [ "btrbk-snapshot.service" ];
        wants = [ "btrbk-snapshot.service" ];
      };
    };

    services.restic.backups = mkIf cfg.remote.enable {
      preserve = {
        inherit (cfg.remote) repository passwordFile;

        paths = [ cfg.snapshotPath ];

        timerConfig = {
          OnCalendar = cfg.remote.schedule;
          Persistent = true;
        };

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

        extraBackupArgs = [
          "--exclude-caches"
          "--one-file-system"
        ];
      }
      // (
        if cfg.remote.b2KeyId != null && cfg.remote.b2ApplicationKey != null then
          {
            package = pkgs.writeShellScriptBin "restic" ''
              set -euo pipefail

              # Validate that secret files exist and are readable
              if [[ ! -f "${cfg.remote.b2KeyId}" ]]; then
                echo "Error: B2 key ID file not found: ${cfg.remote.b2KeyId}" >&2
                exit 1
              fi

              if [[ ! -f "${cfg.remote.b2ApplicationKey}" ]]; then
                echo "Error: B2 application key file not found: ${cfg.remote.b2ApplicationKey}" >&2
                exit 1
              fi

              # Read credentials from secret files
              B2_ACCOUNT_ID="$(cat ${cfg.remote.b2KeyId})"
              B2_ACCOUNT_KEY="$(cat ${cfg.remote.b2ApplicationKey})"

              # Validate that credentials are not empty
              if [[ -z "$B2_ACCOUNT_ID" ]]; then
                echo "Error: B2_ACCOUNT_ID is empty" >&2
                exit 1
              fi

              if [[ -z "$B2_ACCOUNT_KEY" ]]; then
                echo "Error: B2_ACCOUNT_KEY is empty" >&2
                exit 1
              fi

              # Export credentials and execute restic
              export B2_ACCOUNT_ID
              export B2_ACCOUNT_KEY
              exec ${pkgs.restic}/bin/restic "$@"
            '';
          }
        else
          { }
      );
    };
  };
}
