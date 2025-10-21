# Secrets Management

This document describes how secrets are managed using SOPS (Secrets OPerationS).

## Overview

Secrets are stored in a **private flake** called `nix-secrets` that is SSH-cloned from a private repository. The secrets are encrypted using age with host SSH keys.

## Private Flake Structure

The `nix-secrets` repository should have this layout:

```
nix-secrets/
├── flake.nix
├── .sops.yaml              # SOPS configuration
└── hosts/
    ├── odysseus/
    │   └── secrets.yaml    # Encrypted secrets for odysseus
    └── otherhhost/
        └── secrets.yaml    # Encrypted secrets for otherhost
```

## Flake Input

The private secrets flake is referenced in `flake.nix`:

```nix
inputs = {
  nix-secrets = {
    url = "git+ssh://git@github.com/your-username/nix-secrets.git";
    flake = false;  # Just files, not a flake
  };
};
```

## Enabling SOPS in a Host

```nix
# compositions/hosts/<hostname>/default.nix
{
  domains.security.sops = {
    enable = true;
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  sops.secrets = {
    "machine-id" = {
      mode = "0444";
    };
    "passwords/root" = {
      neededForUsers = true;
    };
    "passwords/max" = {
      neededForUsers = true;
    };
    "cachix-token" = { };
  };
}
```

## Secret File Layout

In `nix-secrets/hosts/<hostname>/secrets.yaml`:

```yaml
# Encrypted with sops
machine-id: ENC[AES256_GCM,data:abc123...]
passwords:
  root: ENC[AES256_GCM,data:def456...]
  max: ENC[AES256_GCM,data:ghi789...]
cachix-token: ENC[AES256_GCM,data:jkl012...]
```

## SOPS Configuration

In `nix-secrets/.sops.yaml`:

```yaml
keys:
  # Host public keys (age format)
  - &odysseus age1abcd1234...

creation_rules:
  # Per-host secrets
  - path_regex: hosts/odysseus/secrets.yaml$
    key_groups:
      - age:
          - *odysseus

  - path_regex: hosts/otherhost/secrets.yaml$
    key_groups:
      - age:
          - *otherhost
```

## Initial Setup

### 1. Generate Host SSH Key

On the target host:

```bash
# Generate ED25519 key if not exists
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
```

### 2. Convert SSH Key to Age Format

```bash
# Install ssh-to-age if needed
nix-shell -p ssh-to-age

# Convert public key to age format
ssh-keyscan localhost | ssh-to-age
# Output: age1abcd1234...
```

### 3. Add Key to .sops.yaml

Add the age key to `nix-secrets/.sops.yaml`:

```yaml
keys:
  - &hostname age1abcd1234...

creation_rules:
  - path_regex: hosts/hostname/secrets.yaml$
    key_groups:
      - age:
          - *hostname
```

### 4. Create Secrets File

```bash
cd nix-secrets

# Create directory for host
mkdir -p hosts/hostname

# Create and edit secrets (uses $EDITOR)
sops hosts/hostname/secrets.yaml
```

In the editor, add your secrets in plain YAML:

```yaml
machine-id: "your-machine-id-here"
passwords:
  root: "$y$j9T$..."  # mkpasswd -m yescrypt
  max: "$y$j9T$..."
cachix-token: "your-token-here"
```

Save and exit - sops will encrypt it automatically.

### 5. Commit and Push

```bash
git add .
git commit -m "Add secrets for hostname"
git push
```

## Using Secrets in Configurations

### User Passwords

```nix
# In host configuration
sops.secrets."passwords/root" = {
  neededForUsers = true;
};

users.users.root = {
  hashedPasswordFile = config.sops.secrets."passwords/root".path;
};
```

### Service Tokens

```nix
# In host configuration
sops.secrets."cachix-token" = { };

# Wire to domain
domains.nix.caches.push = {
  enable = true;
  cacheName = "your-cachix";
  tokenFile = config.sops.secrets."cachix-token".path;
};
```

### Custom Service Secrets

```nix
# In host configuration
sops.secrets."api-key" = {
  owner = "myservice";
  group = "myservice";
  mode = "0400";
};

# In service
systemd.services.myservice = {
  serviceConfig = {
    EnvironmentFile = config.sops.secrets."api-key".path;
  };
};
```

## Editing Secrets

```bash
# Edit existing secrets file
cd nix-secrets
sops hosts/hostname/secrets.yaml
```

SOPS will decrypt, open in $EDITOR, then re-encrypt on save.

## Secret Access Patterns

### ❌ Wrong: Hardcoding in Domain

```nix
# domains/nix/caches.nix
tokenFile = mkOption {
  default = config.sops.secrets."cachix-token".path;  # BAD - couples to sops
};
```

### ✅ Correct: Generic Path, Host Wires

```nix
# domains/nix/caches.nix
tokenFile = mkOption {
  type = types.str;
  description = "Path to token file (from sops, agenix, or plain file)";
};

# Host wires it
domains.nix.caches.push = {
  tokenFile = config.sops.secrets."cachix-token".path;
};
```

## Generating Hashed Passwords

```bash
# Generate yescrypt hashed password
mkpasswd -m yescrypt
# Enter password when prompted
# Copy the hash to secrets.yaml
```

## Machine ID

```bash
# Generate a unique machine ID
systemd-id128 new
# Copy to secrets.yaml

# Or use existing if migrating
cat /etc/machine-id
```

## Secret Permissions

Common permission patterns:

```nix
# Readable by service user
sops.secrets."myapp-token" = {
  owner = "myapp";
  group = "myapp";
  mode = "0400";
};

# Readable by group
sops.secrets."shared-key" = {
  owner = "root";
  group = "mygroup";
  mode = "0440";
};

# World-readable (for machine-id, etc.)
sops.secrets."machine-id" = {
  mode = "0444";
};

# Needed during user creation
sops.secrets."passwords/user" = {
  neededForUsers = true;
};
```

## Troubleshooting

### Secret Decryption Fails

1. **Check SSH key exists:**
   ```bash
   ls -l /etc/ssh/ssh_host_ed25519_key
   ```

2. **Verify key in .sops.yaml:**
   ```bash
   # Convert key to age format
   cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
   # Compare with .sops.yaml
   ```

3. **Check secret file was encrypted with this key:**
   ```bash
   cd nix-secrets
   sops -d hosts/hostname/secrets.yaml
   ```

### Permission Denied

1. **Check sops.secrets declaration:**
   ```nix
   sops.secrets."secret-name" = {
     owner = "correct-user";
     mode = "0400";
   };
   ```

2. **Check service user matches:**
   ```nix
   systemd.services.myservice.serviceConfig.User = "correct-user";
   ```

### Path Not Found

Secrets are decrypted to `/run/secrets/` by default:

```bash
# Check if secret was decrypted
ls -l /run/secrets/

# Use config.sops.secrets."name".path in config
domains.feature.tokenFile = config.sops.secrets."token".path;
```

## Security Best Practices

1. **Never commit unencrypted secrets** - sops handles encryption automatically
2. **Use separate secrets per host** - don't share secrets across hosts
3. **Rotate secrets regularly** - especially after team changes
4. **Use restrictive permissions** - 0400 or 0440 for most secrets
5. **Keep nix-secrets private** - use SSH URL, not HTTPS
6. **Back up SSH keys** - store host keys securely; without them, secrets are unrecoverable
7. **Use neededForUsers** - for passwords that must exist before user creation
