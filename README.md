# nix-config: A DDD NixOS Flake

A **Domain-Driven Design (DDD) NixOS configuration** with auto-discovery, ephemeral root, and minimal boilerplate.

## Quick Start

```bash
# 1. Clone and enter repository
git clone <this-repo>
cd nix-config

# 2. Create your first host
cp -r compositions/hosts/odysseus compositions/hosts/<hostname>
# Edit: default.nix, hardware.nix, disko.nix

# 3. Create or copy a user
cp -r compositions/users/max compositions/users/<username>
# Edit: default.nix

# 4. Add user to host
# In compositions/hosts/<hostname>/default.nix:
hostUsers = [ "<username>" ];

# 5. Build and activate
sudo nixos-rebuild switch --flake .#<hostname>
```

## Documentation

| Document | Description |
|----------|-------------|
| **[Architecture](docs/architecture.md)** | DDD principles, domain types, module composition, patterns |
| **[Development](docs/development.md)** | Build commands, formatting, pre-commit hooks, workflows |
| **[Patterns](docs/patterns.md)** | Common configuration templates and examples |
| **[Secrets](docs/secrets.md)** | SOPS secrets management setup and usage |
| **[Troubleshooting](docs/troubleshooting.md)** | Common issues and solutions |

## Key Features

### Auto-Discovery
- **Hosts**: Any directory in `compositions/hosts/*/` is automatically buildable
- **Domains**: Any `.nix` file in `domains/*/` is automatically imported
- **Users**: Referenced via `l.usersForHost hostName ["username"]`

No manual registration needed.

### Domain-Driven Design

Three domain types:

**Capability Domains** - Enable/disable services (has `enable` option):
```nix
domains.security.sops.enable = true;
```

**Configuration Domains** - Set values only (no `enable` option):
```nix
domains.nix.nixpkgs.allowUnfree = true;
```

**Mixed Domains** - Combine both using `mkMerge`:
```nix
domains.nix.caches = {
  extraCaches = [ ... ];  # Configuration (always applies)
  push.enable = true;     # Capability (conditional)
};
```

See [Architecture](docs/architecture.md) for full details.

### Ephemeral Root

Fully implemented using btrfs snapshots:
- Root `/` (`@purge`) is deleted and restored on every boot
- Persistent data in `@persist`, `@preserve`, and `@nix` subvolumes
- Declarative persistence configuration

```nix
domains.storage.btrfs.preservation = {
  enable = true;
  rootSubvolume = "@purge";
  blankSnapshot = "@snapshots/purge-blank";
  mounts."/persist" = {
    neededForBoot = true;
    directories = [ "/etc/ssh" "/var/lib/nixos" ];
  };
};
```

### Secrets Management

Private `nix-secrets` flake with SOPS:
- Age-encrypted secrets using host SSH keys
- Per-host secret files: `hosts/<hostname>/secrets.yaml`
- Decoupled from domains - hosts wire secrets via options

See [Secrets](docs/secrets.md) for setup.

## Project Structure

```
.
├── compositions/
│   ├── hosts/           # Host configurations (auto-discovered)
│   │   └── odysseus/    # Example host
│   └── users/           # User configurations
│       └── max/         # Example user
├── domains/             # Reusable domain modules (auto-discovered)
│   ├── boot/            # Boot loaders (systemd-boot, etc.)
│   ├── nix/             # Nix daemon, caches, nixpkgs, nh
│   ├── security/        # SOPS secrets management
│   └── storage/         # Btrfs, preservation (ephemeral root)
├── lib/                 # Auto-discovery and composition utilities
├── docs/                # Documentation
├── flake.nix            # Flake definition
└── README.md            # This file
```

## Common Commands

```bash
# Build and activate
sudo nixos-rebuild switch --flake .

# Format code
nix fmt

# Run all checks (pre-commit hooks)
nix flake check

# Update flake inputs
nix flake update

# Clean up old generations (if nh enabled)
sudo nh clean all --keep 5 --keep-since 7d
```

See [Development](docs/development.md) for complete command reference.

## Adding Components

| Task | Command | Details |
|------|---------|---------|
| Add host | `cp -r compositions/hosts/odysseus compositions/hosts/<name>` | [Development](docs/development.md#adding-a-new-host) |
| Add user | `cp -r compositions/users/max compositions/users/<name>` | [Development](docs/development.md#adding-a-new-user) |
| Add domain | `touch domains/<category>/<feature>.nix` | [Development](docs/development.md#adding-a-new-domain-module) |

See [Patterns](docs/patterns.md) for templates and examples.

## Philosophy

**Strict DDD Principles:**
- ✅ Bounded contexts - each domain is self-contained
- ✅ Explicit dependencies - no "magic" auto-enabling
- ✅ No cross-domain coupling - composition layer orchestrates
- ✅ Clear error messages - assertions validate configuration

**Anti-patterns (forbidden):**
- ❌ Domains auto-enabling other domains
- ❌ Hardcoded secrets paths in domains
- ❌ Misaligned option names (domain options should match NixOS options)

See [Architecture](docs/architecture.md) for detailed principles and patterns.

## License

This configuration is personal infrastructure. Feel free to reference patterns and structure, but you'll need to adapt it for your own setup (especially secrets and hardware configs).
