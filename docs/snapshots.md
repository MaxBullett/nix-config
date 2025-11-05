# Btrfs Snapshots & Remote Backups

Automated backup system using **btrbk** for local snapshots and **restic** for encrypted, deduplicated remote backups to Backblaze B2.

## Overview

**Architecture:**
1. **btrbk** - Creates periodic local snapshots of btrfs subvolumes
2. **restic** - Backs up snapshots to B2 with encryption and content-addressed deduplication
3. **systemd** - Coordinates timing: snapshots at 01:00, backups at 02:00

**Key Features:**
- ✅ Automatic snapshot creation and rotation
- ✅ End-to-end encryption (age for secrets, restic for backups)
- ✅ Content-addressed deduplication (no chain dependencies!)
- ✅ Configurable retention policies (local vs remote)
- ✅ File-level restores with preserved ownership/permissions

---

## Configuration

### 1. Prerequisites

**Backblaze B2 Setup:**
```
1. Create B2 bucket (e.g., "odysseus-backup")
2. Set Files in Bucket: Private
3. Encryption: None (restic handles client-side encryption)
4. Create Application Key with Read and Write capabilities
5. Save keyID and applicationKey
```

**Add Secrets to sops-nix:**

In `nix-secrets/secrets.yaml`:
```yaml
restic: <generate-strong-password>
b2:
  keyID: <your-b2-key-id>
  applicationKey: <your-b2-application-key>
```

In host configuration:
```nix
sops.secrets = {
  "restic".mode = "0400";
  "b2/keyID".mode = "0400";
  "b2/applicationKey".mode = "0400";
};
```

### 2. Enable Snapshots Module

In `compositions/hosts/<hostname>/default.nix`:

```nix
{
  domains.storage.btrfs.snapshots = {
    enable = true;
    subvolume = "/preserve";           # Required: what to snapshot
    snapshotPath = "/.snapshots/preserve";  # Required: where to store snapshots

    # Optional: local retention (defaults: 7d 4w 0m 0y)
    local.retention = {
      daily = 7;
      weekly = 4;
    };

    # Remote backups
    remote = {
      enable = true;
      repository = "b2:odysseus-backup:/snapshots";
      passwordFile = config.sops.secrets."restic".path;
      b2KeyId = config.sops.secrets."b2/keyID".path;
      b2ApplicationKey = config.sops.secrets."b2/applicationKey".path;

      # Optional: remote retention (defaults: 7d 4w 12m 1y)
      retention = {
        daily = 7;
        weekly = 4;
        monthly = 12;
        yearly = 1;
      };

      # Optional: schedule (default: "daily")
      schedule = "daily";  # Or "02:00" for specific time
    };
  };
}
```

---

## Usage Scenarios

### Scenario 1: First-Time Setup (New System, New Backups)

**Step 1: Deploy Configuration**
```bash
sudo nixos-rebuild switch --flake .#odysseus
```

The system automatically creates the snapshot directory on boot.

**Step 2: Initialize Restic Repository**
```bash
# Set B2 credentials
export B2_ACCOUNT_ID="$(cat /run/secrets/b2/keyID)"
export B2_ACCOUNT_KEY="$(cat /run/secrets/b2/applicationKey)"

# Initialize repository (first time only!)
restic -r b2:odysseus-backup:/snapshots --password-file /run/secrets/restic init
```

**Step 3: Verify Setup**
```bash
# Trigger first snapshot
sudo systemctl start btrbk-snapshot.service

# Check snapshots were created
ls -la /.snapshots/preserve/

# Trigger first backup (will take time on first run)
sudo systemctl start restic-backups-preserve.service

# Monitor progress
sudo journalctl -fu restic-backups-preserve.service
```

**Done!** Automatic backups will run daily.

---

### Scenario 2: System Rebuild (Keep Existing Backups)

You're rebuilding your system from scratch but want to continue using existing backups.

**Critical:** Use the **same restic password** from your nix-secrets repo!

**Step 1: Deploy Configuration**
```bash
sudo nixos-rebuild switch --flake .#odysseus
```

**Step 2: Verify Repository Access**
```bash
# Set B2 credentials
export B2_ACCOUNT_ID="$(cat /run/secrets/b2/keyID)"
export B2_ACCOUNT_KEY="$(cat /run/secrets/b2/applicationKey)"

# List existing snapshots (verifies password and access)
restic -r b2:odysseus-backup:/snapshots --password-file /run/secrets/restic snapshots
```

**If this succeeds:** You're done! Backups will resume automatically.

**If this fails:** Wrong password or repository doesn't exist. See troubleshooting.

---

### Scenario 3: Disaster Recovery (Restore from Backups)

Your system is broken and you need to restore data.

**Step 1: Boot into Recovery Environment**

Use NixOS installation media or another system with network access.

**Step 2: Set Credentials**
```bash
# Manually set credentials (or mount your secrets if available)
export B2_ACCOUNT_ID="<your-key-id>"
export B2_ACCOUNT_KEY="<your-application-key>"
export RESTIC_PASSWORD="<your-restic-password>"
```

**Step 3: List Available Snapshots**
```bash
restic -r b2:odysseus-backup:/snapshots snapshots

# Output shows snapshot IDs and dates
```

**Step 4: Restore Data**

**Option A: Restore specific files/directories**
```bash
# Restore to temporary location
sudo restic -r b2:odysseus-backup:/snapshots restore latest \
  --target /mnt/restore \
  --include /home/max/.config \
  --include /home/max/Documents

# Then copy where needed
```

**Option B: Restore everything**
```bash
# Mount your target filesystem
sudo mount /dev/disk/by-label/preserve /mnt/preserve

# Restore to mounted location
sudo restic -r b2:odysseus-backup:/snapshots restore latest \
  --target /mnt/preserve
```

**Step 5: Verify Ownership**
```bash
# Check restored files have correct ownership
ls -la /mnt/restore/home/max/
```

---

## Daily Operations

### Monitoring

**Check backup status:**
```bash
# Last backup time and status
sudo systemctl status restic-backups-preserve.service

# Recent logs
sudo journalctl -u restic-backups-preserve.service -n 50

# Upcoming scheduled runs
sudo systemctl list-timers | grep -E 'btrbk|restic'
```

**Repository statistics:**
```bash
export B2_ACCOUNT_ID="$(cat /run/secrets/b2/keyID)"
export B2_ACCOUNT_KEY="$(cat /run/secrets/b2/applicationKey)"

restic -r b2:odysseus-backup:/snapshots --password-file /run/secrets/restic stats

# Shows:
# - Total files/size
# - Deduplication ratio
# - Storage used on B2
```

### Manual Operations

**Create snapshot manually:**
```bash
sudo systemctl start btrbk-snapshot.service
ls -la /.snapshots/preserve/
```

**Run backup manually:**
```bash
sudo systemctl start restic-backups-preserve.service
sudo journalctl -fu restic-backups-preserve.service
```

**List remote snapshots:**
```bash
export B2_ACCOUNT_ID="$(cat /run/secrets/b2/keyID)"
export B2_ACCOUNT_KEY="$(cat /run/secrets/b2/applicationKey)"

restic -r b2:odysseus-backup:/snapshots --password-file /run/secrets/restic snapshots
```

**Check repository integrity:**
```bash
restic -r b2:odysseus-backup:/snapshots --password-file /run/secrets/restic check
```

---

## Troubleshooting

### Error: "Fatal: unable to open config file"

**Cause:** Restic repository not initialized.

**Solution:**
```bash
export B2_ACCOUNT_ID="$(cat /run/secrets/b2/keyID)"
export B2_ACCOUNT_KEY="$(cat /run/secrets/b2/applicationKey)"
restic -r b2:odysseus-backup:/snapshots --password-file /run/secrets/restic init
```

### Error: "wrong password or no key found"

**Cause:** Restic password doesn't match repository.

**Solution:**
- Verify `/run/secrets/restic` contains correct password
- If rebuilding: ensure using same password from nix-secrets
- If lost: repository cannot be decrypted (backups inaccessible)

### Error: "B2 authentication failed"

**Cause:** Invalid B2 credentials.

**Solution:**
```bash
# Check secrets are accessible
cat /run/secrets/b2/keyID
cat /run/secrets/b2/applicationKey

# Verify they match your Backblaze account
```

### Error: "snapshot directory does not exist"

**Cause:** Snapshot directory wasn't created.

**Solution:**
```bash
# Should be created automatically via systemd.tmpfiles.rules
# Manually create if needed:
sudo mkdir -p /.snapshots/preserve
```

### Backups running but taking too long

**Cause:** First backup uploads all data (~500GB).

**Solution:**
- First backup is always large (full upload)
- Subsequent backups only upload changed chunks (~5GB/day)
- Monitor progress: `sudo journalctl -fu restic-backups-preserve.service`

---

## Cost Estimation

**Backblaze B2 Pricing (2025):**
- Storage: $0.005/GB/month
- Downloads: $0.01/GB (for restores)
- Uploads: Free

**Example:** 500GB @preserve with 5GB/day changes

| Retention | Snapshots | Storage After Dedup | Monthly Cost |
|-----------|-----------|---------------------|--------------|
| 7d 4w 12m 1y | ~50 | ~750GB | ~$3.75/month |

**Note:** Restic's content-addressed deduplication significantly reduces storage. Only unique chunks are stored.

---

## Technical Details

### Encryption

**Two-layer security:**
1. **Secrets at rest:** Age encryption via sops-nix
2. **Backups in transit/storage:** Restic's encryption

Your restic password is encrypted with age in sops-nix. Restic then uses this password to encrypt all data sent to B2. Even Backblaze cannot decrypt your backups without the password.

### Deduplication

**Content-addressed storage:**
- Files split into variable-size chunks (~1MB)
- Each chunk hashed (SHA-256)
- Only new/changed chunks uploaded
- No chain dependencies between snapshots

**Advantages:**
- Delete old snapshots without breaking others
- Incremental backups without complex parent/child chains
- Efficient storage (deduplicated across all snapshots)

### Retention Policies

**Local retention (default: 7d 4w):**
- Snapshots on local disk in `/.snapshots/preserve/`
- Btrfs snapshots are cheap (COW, minimal space)
- Quick access for recent restores

**Remote retention (default: 7d 4w 12m 1y):**
- Snapshots on Backblaze B2
- Long-term archival (yearly backups kept 1 year)
- Automatic pruning via restic

### Schedule

**Default timing:**
- **01:00:** btrbk creates local snapshots
- **02:00:** restic backs up snapshots to B2

**Why this order:** Restic needs stable snapshots. By running btrbk first, restic always backs up a consistent point-in-time view.

---

## Related Documentation

- [Architecture Overview](architecture.md) - DDD principles and domain structure
- [Btrfs Preservation](../domains/storage/btrfs/preservation.nix) - Ephemeral root setup
- [SOPS Secrets Management](../domains/security/sops.nix) - How secrets are encrypted
