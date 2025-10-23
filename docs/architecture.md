# Architecture

This document describes the architectural principles and patterns used in this NixOS configuration.

## Overview

This is a **Domain-Driven Design (DDD) NixOS configuration flake** with three layers:

1. **Library** (`lib/`) - Auto-discovery and composition utilities
2. **Domains** (`domains/`) - Reusable NixOS capabilities (boot, security, storage, nix, etc.)
3. **Compositions** (`compositions/`) - Host and user configurations

## Auto-Discovery

The system automatically discovers components from the filesystem:

- **Hosts**: Any directory in `compositions/hosts/*/` becomes a buildable configuration
- **Domains**: Any `.nix` file in `domains/*/` (except `default.nix` at domain root)
- **Users**: Referenced via `l.usersForHost hostName ["username"]`

No manual registration needed - just create the files in the right location.

## Module Composition Order

When building a host, modules are loaded in this order (defined in `lib/default.nix:64-81`):

1. All domain modules (alphabetically sorted)
2. Home Manager module
3. Disko module
4. `hardware.nix` (if exists)
5. `disko.nix` (if exists)
6. Host's `default.nix`
7. User modules from `l.usersForHost`

## Domain Module Types

### Capability Domains

**Purpose:** Enable services, functionality, or features that can be started/stopped

**Requirements:**
- MUST have `enable` option
- Use `mkIf cfg.enable { ... }` for conditional activation
- Examples: boot loaders, services, systemd timers, daemon features

**Example:**
```nix
# domains/security/sops.nix
options.domains.security.sops.enable = mkEnableOption "SOPS secrets management";

config = mkIf cfg.enable {
  sops = {
    defaultSopsFile = "${inputs.nix-secrets}/hosts/${hostName}/secrets.yaml";
    age.sshKeyPaths = cfg.sshKeyPaths;
  };
};
```

### Configuration Domains

**Purpose:** Set configuration values without enabling/disabling functionality

**Requirements:**
- NO `enable` option
- Config always applies: `config = { ... }`
- Examples: package permissions, cache settings, build parameters

**Example:**
```nix
# domains/nix/nixpkgs.nix
options.domains.nix.nixpkgs = {
  allowUnfree = mkOption { ... };
  allowInsecure = mkOption { ... };
};

config = {
  nixpkgs.config.inherit (cfg)
    allowUnfree
    allowInsecure
    ;
};
```

### Mixed Domains

**Purpose:** Combine both Configuration (always-on base) and Capability (optional features)

**Requirements:**
- Use `mkMerge` to separate concerns
- Base configuration in first block (no conditions)
- Optional capabilities in `mkIf cfg.feature.enable` blocks

**Example:**
```nix
# domains/nix/caches.nix
config = mkMerge [
  # Configuration (always applies)
  {
    nix.settings = {
      substituters = map (cache: cache.url) allCaches;
      trusted-public-keys = ...;
    };
  }

  # Capability (conditional)
  (mkIf cfg.push.enable {
    nix.settings.post-build-hook = ...;
  })
];
```

## DDD Principles

### Bounded Contexts

Each domain is self-contained with clear boundaries. Domains follow the namespace pattern:

```nix
options.domains.<category>.<feature>.<option> = ...;
```

Examples:
- `domains.storage.btrfs.preservation.enable`
- `domains.nix.daemon.auto-optimise-store`
- `domains.security.sops.sshKeyPaths`

### Explicit Dependencies

**No "magic" auto-enabling.** Hosts must explicitly declare all required domains.

```nix
# ✅ Correct: Explicit orchestration in host
domains = {
  storage.btrfs.enable = true;
  storage.btrfs.preservation.enable = true;  # Both required
};
```

```nix
# ❌ Wrong: Domain auto-enabling another domain
config = mkIf cfg.enable {
  domains.parent.enable = mkDefault true;  # FORBIDDEN
};
```

### No Cross-Domain Coupling

Domains cannot modify each other. The composition layer (hosts) handles all wiring.

```nix
# ❌ Wrong: Domain modifying another domain
config = mkIf cfg.enable {
  domains.security.sops.secrets = { ... };  # FORBIDDEN
};
```

```nix
# ✅ Correct: Host orchestrates both domains
domains.nix.caches.push = {
  enable = true;
  tokenFile = config.sops.secrets."cachix-token".path;  # Host wires it
};
```

### Conditional Activation

Capability domains use conditional activation with `mkIf`:

```nix
options.domains.category.feature.enable = mkEnableOption "...";

config = mkIf cfg.enable {
  # Implementation only applies when explicitly enabled
};
```

### Assertions

Use assertions to validate dependencies and provide clear error messages:

```nix
config = mkIf cfg.enable {
  assertions = [
    {
      assertion = cfg.tokenFile != "";
      message = "domains.nix.caches.push.tokenFile must be set";
    }
    {
      assertion = builtins.elem "flakes" (config.nix.settings.experimental-features or []);
      message = "domains.nix.nh requires flakes to be enabled";
    }
  ];
};
```

**Important:** Check actual NixOS config values, not other domain options, to avoid coupling.

### Conditional Persistence

Domains are responsible for declaring their own persistence needs when using ephemeral root. This is a **one-way dependency** on the preservation platform, not cross-domain coupling.

**Rationale:** Each domain knows what data it needs to persist. Declaring this in the domain:
- Maintains bounded contexts (domain owns its data requirements)
- Zero boilerplate for users (automatic persistence)
- Self-documenting (persistence declared alongside the feature)
- Graceful degradation (works even if preservation disabled)

**Pattern:**
```nix
config = mkIf cfg.enable {
  # Domain's normal configuration
  networking.networkmanager.enable = true;

  # Conditional persistence (only if ephemeral root enabled)
  domains.storage.btrfs.preservation.mounts."/persist".directories =
    mkIf config.domains.storage.btrfs.preservation.enable [
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
    ];
};
```

**Why this doesn't violate "No Cross-Domain Coupling":**

This is analogous to using NixOS platform options like `networking.*` or `services.*`. Domains are:
- **Not modifying another domain's behavior** (preservation's logic is unchanged)
- **Contributing to a shared platform interface** (preservation provides options for this purpose)
- **Following a one-way dependency** (domain → platform, not bidirectional)

The preservation domain provides options specifically designed for domains to contribute to, similar to how NixOS provides `environment.systemPackages` for packages or `users.users` for user definitions.

**When preservation is disabled:** The paths simply don't get added (NixOS module system handles the merge), and the system works normally with persistent root.

## Anti-Patterns (Forbidden)

### Auto-Enabling Other Domains

```nix
# ❌ NEVER do this
config = mkIf cfg.enable {
  domains.parent.enable = mkDefault true;
};
```

### Cross-Domain Modification

```nix
# ❌ NEVER modify another domain
config = mkIf cfg.enable {
  domains.other.feature.setting = "value";
};
```

### Hardcoded Secrets Paths

```nix
# ❌ Wrong: Couples domain to specific secret management
tokenFile = mkOption {
  default = config.sops.secrets."token".path;
};
```

```nix
# ✅ Correct: Generic path, host provides
tokenFile = mkOption {
  type = types.str;
  description = "Path to token file (e.g., from sops, agenix, or plain file)";
};
```

### Misaligned Option Names

```nix
# ❌ Wrong: Name doesn't match underlying option
options.domains.nix.daemon.autoOptimise = mkOption { ... };

config = {
  nix.settings.auto-optimise-store = cfg.autoOptimise;
};
```

```nix
# ✅ Correct: Names align, use inherit
options.domains.nix.daemon.auto-optimise-store = mkOption { ... };

config = {
  nix.settings.inherit (cfg) auto-optimise-store;
};
```

## Code Conventions

### Option Naming

Domain option names should match the underlying NixOS options they configure:

- Use kebab-case (e.g., `auto-optimise-store`, not `autoOptimise`)
- Match NixOS option names exactly when possible
- Enables cleaner code via `inherit` pattern

### Inherit Pattern

When option names align with their assignments, use `inherit`:

```nix
# ✅ Preferred
nix.settings.inherit (cfg)
  auto-optimise-store
  max-jobs
  cores
  ;
```

```nix
# ❌ Verbose (only use when names don't align)
nix.settings = {
  auto-optimise-store = cfg.auto-optimise-store;
  max-jobs = cfg.max-jobs;
  cores = cfg.cores;
};
```

## Special Arguments

These are available in all modules via `specialArgs`:

- `inputs` - Flake inputs (nixpkgs, home-manager, nix-secrets, etc.)
- `l` - Library functions from `lib/default.nix`
- `hostName` - Current host name

## Library Functions

Key functions exposed via `l` (defined in `lib/default.nix`):

- `l.listHostNames` - List all discovered hosts
- `l.systemForHost host` - Get system architecture for a host
- `l.mkHostModules host extraModules` - Build module list for a host
- `l.usersForHost host users` - Resolve user module paths
- `l.domainModulePaths` - List all discovered domain module paths
- `l.autoDomainImports` - All domain modules as imports
