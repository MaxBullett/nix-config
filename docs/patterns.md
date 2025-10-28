# Common Patterns

This document provides templates and examples for common configuration patterns.

## Host Configuration Patterns

### Basic Host Template

```nix
# compositions/hosts/<hostname>/default.nix
{
  config,
  l,
  hostName ? "<hostname>",
  ...
}:
let
  hostUsers = [ "max" ];
in
{
  imports = l.usersForHost hostName hostUsers;

  networking.hostName = hostName;
  time.timeZone = "Europe/Berlin";

  domains = {
    # Boot
    boot.systemd-boot.enable = true;

    # Security
    security.sops = {
      enable = true;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    # Storage
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
            directories = [ "/etc/ssh" "/var/lib/nixos" ];
          };
        };
      };
    };

    # Nix
    nix = {
      daemon = {
        auto-optimise-store = true;
        max-jobs = "auto";
      };
      nh = {
        enable = true;
        clean.enable = true;
      };
      nixpkgs.allowUnfree = true;
    };
  };

  # Home Manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  system.stateVersion = "25.05";
}
```

### Enabling Domains

```nix
# Capability domain - requires enable
domains.security.sops.enable = true;

# Configuration domain - no enable, just set values
domains.nix.nixpkgs.allowUnfree = true;

# Hierarchical domains - enable both parent and child
domains.storage.btrfs.enable = true;
domains.storage.btrfs.preservation.enable = true;
```

### Host-Specific Secrets

```nix
# In host configuration
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
};

# Wire secrets to domain options
domains.nix.caches.push = {
  enable = true;
  tokenFile = config.sops.secrets."cachix-token".path;
};
```

## User Configuration Patterns

### Complete User Configuration

**All user configuration should be in a single file** (`default.nix`):

```nix
# compositions/users/<username>/default.nix
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  userName = "max";
  secretKey = "passwords/${userName}";
in
{
  # SOPS secrets
  sops.secrets."${secretKey}" = {
    sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
    neededForUsers = true;
  };

  # System-level user configuration
  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    hashedPasswordFile = config.sops.secrets."${secretKey}".path;
  };

  # Home Manager configuration
  home-manager.users.${userName} = {
    # Home settings
    home = {
      username = userName;
      homeDirectory = "/home/${userName}";
      packages = with pkgs; [
        vim
        htop
        ripgrep
        fd
      ];
      stateVersion = "25.05";
    };

    # Programs
    programs.git = {
      enable = true;
      userName = "Max";
      userEmail = "max@example.com";
    };
  };
}
```

### Host-Specific User Override

```nix
# compositions/users/<username>/hosts/<hostname>.nix
{ pkgs, ... }:
{
  # Override for this specific host
  home.packages = with pkgs; [
    # Host-specific packages
    docker
    kubectl
  ];

  programs.git.extraConfig = {
    user.signingkey = "ABCD1234";
  };
}
```

### Hybrid Domain User Config (Home-Manager)

**For domains that need both system and user configuration** (shells, editors, etc.):

```nix
# compositions/users/<username>/default.nix
{
  config,
  pkgs,
  ...
}:
let
  userName = "max";
in
{
  # System-level user setup
  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    # Note: shell is set automatically by the nushell domain
  };

  # Home-manager configuration with hybrid domains
  home-manager.users.${userName} = {
    # Nushell configuration (hybrid domain)
    domains.shell.nushell = {
      enable = true;
      plugins = with pkgs.nushellPlugins; [
        polars
        gstat
        formats
        query
        net
        desktop_notifications
      ];
      shellAliases = {
        ll = "ls -l";
        la = "ls -la";
        ".." = "cd ..";
        "..." = "cd ../..";
      };
    };

    # Editor configuration (hybrid domain - when implemented)
    domains.editors.helix = {
      enable = true;
      command = "hx";
      # ... helix-specific options
    };

    # Other home-manager config
    home.packages = with pkgs; [
      htop
      ripgrep
      fd
    ];

    home.stateVersion = "25.05";
  };
}
```

**Key benefits:**
- No username repetition (`domains.shell.nushell.max` → `domains.shell.nushell`)
- Domain automatically handles both system setup and user config
- Type-safe configuration with clear option types
- Persistence automatically managed by the domain

## Domain Module Patterns

### Capability Domain Template

```nix
# domains/<category>/<feature>.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.domains.<category>.<feature>;
in
{
  options.domains.<category>.<feature> = {
    enable = mkEnableOption "<feature description>";

    option1 = mkOption {
      type = types.str;
      default = "value";
      description = "Description of option1";
    };

    option2 = mkOption {
      type = types.int;
      default = 10;
      description = "Description of option2";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.option1 != "";
        message = "domains.<category>.<feature>.option1 must be set";
      }
    ];

    # Implementation
    systemd.services.my-service = {
      enable = true;
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.my-package}/bin/my-command";
      };
    };
  };
}
```

### Configuration Domain Template

```nix
# domains/<category>/<feature>.nix
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.domains.<category>.<feature>;
in
{
  options.domains.<category>.<feature> = {
    option1 = mkOption {
      type = types.bool;
      default = false;
      description = "Description of option1";
    };

    option2 = mkOption {
      type = types.str;
      default = "value";
      description = "Description of option2";
    };
  };

  config = {
    # Always applies - no mkIf
    system.feature.inherit (cfg)
      option1
      option2
      ;
  };
}
```

### Mixed Domain Template

```nix
# domains/<category>/<feature>.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkMerge mkOption types;
  cfg = config.domains.<category>.<feature>;
in
{
  options.domains.<category>.<feature> = {
    # Configuration options (no enable)
    baseOption = mkOption {
      type = types.str;
      default = "value";
      description = "Always-active configuration";
    };

    # Capability section
    capability = {
      enable = mkEnableOption "optional capability";

      setting = mkOption {
        type = types.int;
        default = 10;
        description = "Capability-specific setting";
      };
    };
  };

  config = mkMerge [
    # Configuration (always applies)
    {
      system.feature.base = cfg.baseOption;
    }

    # Capability (conditional)
    (mkIf cfg.capability.enable {
      assertions = [
        {
          assertion = cfg.capability.setting > 0;
          message = "domains.<category>.<feature>.capability.setting must be positive";
        }
      ];

      systemd.services.optional-service = {
        enable = true;
        # ... service config
      };
    })
  ];
}
```

### Hierarchical Domain Pattern

```nix
# Parent: domains/storage/btrfs.nix
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.domains.storage.btrfs;
in
{
  options.domains.storage.btrfs.enable = mkEnableOption "Btrfs filesystem support";

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "btrfs" ];
  };
}

# Child: domains/storage/btrfs/preservation.nix
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  btrfs_cfg = config.domains.storage.btrfs;
  cfg = btrfs_cfg.preservation;
in
{
  options.domains.storage.btrfs.preservation = {
    enable = mkEnableOption "ephemeral root via btrfs snapshots";

    rootSubvolume = mkOption {
      type = types.str;
      description = "Subvolume to purge on boot";
      example = "@purge";
    };

    blankSnapshot = mkOption {
      type = types.str;
      description = "Blank snapshot to restore from";
      example = "@snapshots/purge-blank";
    };
  };

  config = mkIf (btrfs_cfg.enable && cfg.enable) {
    assertions = [
      {
        assertion = btrfs_cfg.enable;
        message = "domains.storage.btrfs.preservation requires domains.storage.btrfs.enable = true";
      }
      {
        assertion = cfg.rootSubvolume != "";
        message = "domains.storage.btrfs.preservation.rootSubvolume must be set";
      }
    ];

    # Implementation
  };
}
```

## Persistence Patterns

### Persisting System Directories

```nix
domains.storage.btrfs.preservation.mounts."/persist" = {
  neededForBoot = true;
  directories = [
    "/etc/ssh"
    "/etc/nixos"
    "/var/lib/nixos"
    "/var/lib/systemd"
    "/var/log"
    {
      directory = "/var/lib/private";
      mode = "0700";
    }
  ];
};
```

### Persisting System Files

```nix
domains.storage.btrfs.preservation.mounts."/persist" = {
  files = [
    "/etc/machine-id"
    {
      file = "/var/lib/logrotate.status";
      mode = "0600";
      how = "symlink";
    }
  ];
};
```

### Persisting User Data

```nix
domains.storage.btrfs.preservation.mounts."/persist" = {
  users.max = {
    directories = [
      ".ssh"
      ".gnupg"
      ".local/share"
      {
        directory = ".config";
        mode = "0700";
      }
    ];
    files = [
      ".bashrc"
      ".zshrc"
    ];
  };
};
```

## Nix Configuration Patterns

### Binary Caches

```nix
# Add custom caches
domains.nix.caches = {
  extraCaches = [
    {
      url = "https://your-cache.cachix.org";
      key = "your-cache.cachix.org-1:abcd1234...";
    }
  ];
  require-sigs = true;
};
```

### Smart Cachix Push

```nix
# Only push builds unique to your setup
sops.secrets."cachix-token" = { };

domains.nix.caches.push = {
  enable = true;
  cacheName = "your-cachix";
  tokenFile = config.sops.secrets."cachix-token".path;
  # Automatically skips paths found in public caches
};
```

### Build Optimization

```nix
domains.nix.daemon = {
  auto-optimise-store = true;
  max-jobs = "auto";  # Or specific number like 4
  cores = 0;  # 0 = all cores per job
  builders-use-substitutes = true;
  download-buffer-size = 500 * 1024 * 1024;  # 500MB
};
```

### Garbage Collection

```nix
# Option 1: Use nh (recommended)
domains.nix.nh = {
  enable = true;
  clean = {
    enable = true;
    dates = "weekly";
    extraArgs = "--keep 5 --keep-since 7d";
  };
};

# Option 2: Use native nix gc (conflicts with nh.clean)
domains.nix.daemon.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

## Btrfs Subvolume Layout

Standard layout used across hosts:

```
/dev/nvme0n1p2 (btrfs)
├── @purge           → /           (ephemeral, purged on boot)
├── @nix             → /nix        (persistent Nix store)
├── @persist         → /persist    (boot-critical persistent state)
├── @preserve        → /preserve   (long-term user data)
└── @snapshots       → /.snapshots (snapshot storage)
    └── purge-blank               (blank root snapshot for restoration)
```

### Disko Configuration Template

```nix
# compositions/hosts/<hostname>/disko.nix
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";  # Update this!
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@purge" = {
                    mountpoint = "/";
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "noatime" ];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "noatime" ];
                  };
                  "@preserve" = {
                    mountpoint = "/preserve";
                    mountOptions = [ "noatime" ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
```
