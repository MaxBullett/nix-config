# Troubleshooting

This document covers common issues and their solutions.

## Module Discovery Issues

### Module Not Found

**Symptom:** Domain module isn't being imported, options are undefined.

**Diagnosis:**
```bash
# Check what modules are discovered
nix eval .#lib.domainModulePaths

# Expected output includes your module:
# [ "/.../domains/category/feature.nix" ... ]
```

**Common causes:**
1. **File named `default.nix` at domain root** - Only `domains/category/feature/default.nix` works, not `domains/category/default.nix`
2. **Wrong extension** - Must be `.nix`
3. **Wrong location** - Must be in `domains/*/`

**Solutions:**
```bash
# ❌ Wrong
domains/nix/default.nix

# ✅ Correct
domains/nix/daemon.nix
# OR
domains/nix/daemon/default.nix
```

### Host Not Found

**Symptom:** Can't build host with `--flake .#hostname`

**Diagnosis:**
```bash
# List discovered hosts
nix eval .#lib.listHostNames

# Show all available configurations
nix flake show
```

**Common causes:**
1. Directory doesn't exist in `compositions/hosts/`
2. Missing required files (default.nix)

**Solution:**
```bash
# Ensure structure exists
ls compositions/hosts/hostname/
# Should show: default.nix  disko.nix  hardware.nix
```

## Build Failures

### Assertion Failures

**Symptom:** Build fails with assertion message.

**Example error:**
```
error: Failed assertions:
- domains.storage.btrfs.preservation requires domains.storage.btrfs.enable = true
```

**Solution:** Read the assertion message - it tells you exactly what's wrong:
```nix
# Enable the required parent domain
domains.storage.btrfs.enable = true;
domains.storage.btrfs.preservation.enable = true;
```

### Type Mismatch

**Symptom:** Error about wrong type.

**Example error:**
```
error: value is a string while a signed integer or value "auto" was expected
```

**Common causes:**
1. Option type doesn't match what NixOS expects
2. Passing wrong value type

**Solution:** Check option definition and pass correct type:
```nix
# ❌ Wrong - string when int expected
max-jobs = "4";

# ✅ Correct - int
max-jobs = 4;

# ✅ Also correct - special string value
max-jobs = "auto";
```

### Infinite Recursion

**Symptom:** `error: infinite recursion encountered`

**Common causes:**
1. Module trying to access its own options during evaluation
2. Circular dependencies between options

**Solution:** Use `mkDefault`, `mkBefore`, or `mkAfter` to break cycles:
```nix
# ❌ Wrong - circular
option1 = cfg.option2;
option2 = cfg.option1;

# ✅ Correct - no interdependence
option1 = mkDefault "value1";
option2 = mkDefault "value2";
```

## Secrets Issues

### Decryption Fails

**Symptom:** Error about failed to decrypt secret.

**Diagnosis:**
```bash
# Check SSH key exists
ls -l /etc/ssh/ssh_host_ed25519_key

# Verify key can decrypt manually
cd nix-secrets
sops -d hosts/hostname/secrets.yaml
```

**Common causes:**
1. SSH key doesn't exist (first boot)
2. Key not in `.sops.yaml`
3. Secret encrypted with wrong key

**Solutions:**
```bash
# 1. Generate host SSH key (if missing)
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

# 2. Convert to age format and add to .sops.yaml
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

# 3. Re-encrypt secrets with new key
cd nix-secrets
sops updatekeys hosts/hostname/secrets.yaml
```

### Secret Path Not Found

**Symptom:** Service can't find secret file.

**Common causes:**
1. Secret not declared in host config
2. Wrong path used
3. Service starts before secret is decrypted

**Solution:**
```nix
# 1. Declare secret
sops.secrets."my-secret" = { };

# 2. Use config.sops.secrets."name".path
domains.feature.secretFile = config.sops.secrets."my-secret".path;
# NOT: /run/secrets/my-secret (might work but fragile)

# 3. If needed before boot
sops.secrets."my-secret" = {
  neededForUsers = true;  # Or other early-boot flag
};
```

### Permission Denied

**Symptom:** Service can't read secret file.

**Diagnosis:**
```bash
# Check actual permissions
ls -l /run/secrets/

# Check service user
systemctl status myservice.service
```

**Solution:**
```nix
# Match secret owner to service user
sops.secrets."my-secret" = {
  owner = "myservice";
  group = "myservice";
  mode = "0400";
};

systemd.services.myservice.serviceConfig.User = "myservice";
```

## Ephemeral Root Issues

### Files Disappear After Reboot

**Symptom:** Configuration or data lost after reboot.

**Cause:** Files not in persistent subvolumes.

**Solution:** Add paths to preservation mounts:
```nix
domains.storage.btrfs.preservation.mounts."/persist" = {
  neededForBoot = true;
  directories = [
    "/etc/important-config"
    "/var/lib/myservice"
  ];
  files = [
    "/etc/myapp.conf"
  ];
};
```

### Boot Fails - Can't Find Root

**Symptom:** Initrd fails to find root filesystem.

**Diagnosis:**
```bash
# Check journal from previous boot
journalctl -b -1 -u purge-root

# Check subvolume exists
sudo btrfs subvolume list /
```

**Common causes:**
1. Subvolume names don't match configuration
2. Blank snapshot missing
3. Wrong device in configuration

**Solution:**
```nix
# Ensure names match actual subvolumes
domains.storage.btrfs.preservation = {
  rootSubvolume = "@purge";  # Must exist
  blankSnapshot = "@snapshots/purge-blank";  # Must exist
};
```

### Initrd Service Fails

**Symptom:** `purge-root` service fails in initrd.

**Diagnosis:**
```bash
# Check service status
systemctl status purge-root

# Check what paths need to be in initrd
ls /persist/var/lib/nixos
```

**Solution:**
```nix
# Mark directories needed in initrd
domains.storage.btrfs.preservation.mounts."/persist".directories = [
  {
    directory = "/var/lib/nixos";
    inInitrd = true;  # Available in initrd
  }
];
```

## Garbage Collection Conflicts

### Warning About GC Conflict

**Symptom:** Warning that both `nh.clean` and `nix.gc.automatic` are enabled.

**Solution:** Choose one method:
```nix
# Option 1: Use nh (recommended)
domains.nix.nh.clean.enable = true;
# Ensure daemon.gc.automatic is NOT enabled

# Option 2: Use native gc
domains.nix.daemon.gc.automatic = true;
# Ensure nh.clean.enable is false
```

## Cache Issues

### Builds Not Using Cache

**Symptom:** Packages building from source despite cache being configured.

**Diagnosis:**
```bash
# Check substituters
nix show-config | grep substituters

# Test cache manually
nix path-info --store https://cache.nixos.org /nix/store/...
```

**Common causes:**
1. Cache not in substituters list
2. Signatures required but key missing
3. Network/firewall issues

**Solution:**
```nix
# Ensure caches are configured
domains.nix.caches = {
  extraCaches = [
    {
      url = "https://your-cache.cachix.org";
      key = "your-cache.cachix.org-1:...";
    }
  ];
  require-sigs = true;
};
```

### Cachix Push Fails

**Symptom:** Post-build hook errors when pushing to cachix.

**Diagnosis:**
```bash
# Check if token is accessible
cat /run/secrets/cachix-token

# Check cachix auth
cachix authtoken /run/secrets/cachix-token
cachix use your-cache
```

**Common causes:**
1. Token not set or wrong path
2. Token expired or invalid
3. Network issues

**Solution:**
```nix
# Ensure token is properly configured
sops.secrets."cachix-token" = { };

domains.nix.caches.push = {
  enable = true;
  cacheName = "your-cachix";  # Must match your cachix cache name
  tokenFile = config.sops.secrets."cachix-token".path;
};
```

## Formatting Issues

### Statix Warnings

**Symptom:** `nix flake check` shows statix warnings.

**Common warnings:**
```
warning: Useless use of inherit - use let binding instead
```

**Solution:** Follow the warning's suggestion:
```nix
# If statix suggests using inherit, use it:
nix.settings.inherit (cfg)
  auto-optimise-store
  max-jobs
  cores
  ;
```

### Nixfmt Changes

**Symptom:** Pre-commit hook modifies files.

**This is normal!** Just stage the changes:
```bash
git add .
git commit
```

To format manually before commit:
```bash
nix fmt
```

## Performance Issues

### Slow Builds

**Diagnosis:**
```bash
# Check build job configuration
nix show-config | grep max-jobs
nix show-config | grep cores
```

**Solutions:**
```nix
# Optimize build settings
domains.nix.daemon = {
  max-jobs = "auto";  # Or specific number
  cores = 0;  # Use all cores per job
  download-buffer-size = 500 * 1024 * 1024;  # 500MB
};
```

### Large Store Size

**Diagnosis:**
```bash
# Check store size
du -sh /nix/store

# Find largest paths
nix path-info --recursive --size --closure-size /run/current-system | sort -k2 -h | tail -20
```

**Solutions:**
```bash
# Run garbage collection
sudo nh clean all --keep 5 --keep-since 7d

# Or manual
sudo nix-collect-garbage --delete-older-than 30d
sudo nix-store --optimize
```

```nix
# Enable automatic cleanup
domains.nix.nh.clean = {
  enable = true;
  dates = "weekly";
  extraArgs = "--keep 5 --keep-since 7d";
};
```

## Git Issues

### Pre-commit Hook Blocks Commit

**Symptom:** Git commit rejected by pre-commit hook.

**Solutions:**
```bash
# Fix the issue the hook identified, then commit again

# Or temporarily bypass (not recommended)
git commit --no-verify

# Or disable specific hook
pre-commit run --hook-stage manual
```

### Flake.lock Conflicts

**Symptom:** Merge conflicts in `flake.lock`.

**Solution:**
```bash
# Accept one version and regenerate
git checkout --theirs flake.lock  # or --ours
nix flake update
git add flake.lock
git commit
```

## Getting More Help

### Enable Debug Output

```bash
# More verbose build output
nixos-rebuild switch --flake .#hostname --show-trace

# Full evaluation trace
nixos-rebuild switch --flake .#hostname --show-trace --verbose
```

### Check Specific Module Evaluation

```bash
# Evaluate specific domain options
nix eval .#nixosConfigurations.hostname.config.domains.category.feature

# See full config
nix eval .#nixosConfigurations.hostname.config --json | jq
```

### Inspect What Changed

```bash
# Compare with previous generation
nix store diff-closures /nix/var/nix/profiles/system-*-link

# See what will change
nixos-rebuild build --flake .#hostname
nix store diff-closures /run/current-system ./result
```
