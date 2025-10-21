# Development

This document covers the development workflow, build commands, and tooling.

## Building & Deploying

### Build and Activate

```bash
# Build and activate a specific host (requires sudo)
sudo nixos-rebuild switch --flake .#<hostname>

# Build and activate current host (auto-detects hostname)
sudo nixos-rebuild switch --flake .
```

### Build Without Activating

```bash
# Build without activating (useful for testing)
sudo nixos-rebuild build --flake .#<hostname>

# Test build in a VM
nixos-rebuild build-vm --flake .#<hostname>
```

### Using nh (if enabled)

If you've enabled `domains.nix.nh.enable = true` in your host:

```bash
# Build and activate with better output
nh os switch

# Build without activating
nh os build

# Test in VM
nh os test
```

## Formatting & Linting

### Format Code

```bash
# Format all Nix files using nixfmt-rfc-style
nix fmt
```

This automatically formats all `.nix` files in the repository according to RFC style.

### Run All Checks

```bash
# Run all pre-commit checks
nix flake check
```

This runs:
- **Nix checks**: deadnix, flake-checker, nixfmt-rfc-style, statix
- **Shell checks**: shellcheck, shfmt
- **General checks**: Large files, merge conflicts, private keys, trailing whitespace

## Pre-commit Hooks

### Install Hooks

```bash
# One-time setup per clone
nix develop -c pre-commit install
```

After installation, hooks run automatically on `git commit`.

### Manually Run Hooks

```bash
# Run hooks on all files
nix develop -c pre-commit run --all-files

# Run specific hook
nix develop -c pre-commit run nixfmt --all-files
```

### Available Hooks

Configured in `checks.nix`:

**Nix:**
- `deadnix` - Detect unused Nix code
- `flake-checker` - Validate flake structure
- `nixfmt-rfc-style` - Format Nix code
- `statix` - Lint Nix code (no deprecated patterns, etc.)

**Shell:**
- `shellcheck` - Lint shell scripts
- `shfmt` - Format shell scripts

**General:**
- `check-added-large-files` - Prevent large files (>500KB)
- `check-merge-conflict` - Detect merge conflict markers
- `detect-private-keys` - Prevent committing private keys
- `trim-trailing-whitespace` - Remove trailing whitespace

## Development Shell

### Enter Shell

```bash
# Enter development shell with all tools
nix develop
```

This provides:
- Pre-commit hooks
- All formatting tools
- Build utilities

### Shell Without Installing Hooks

```bash
# Just get the tools, don't install hooks
nix develop --command bash
```

## Adding Components

### Adding a New Host

1. **Copy template:**
   ```bash
   cp -r compositions/hosts/odysseus compositions/hosts/<hostname>
   ```

2. **Edit three files:**
   - `default.nix` - Set `hostName`, `hostUsers`, timezone, enable domains
   - `hardware.nix` - Run `nixos-generate-config` and copy `hardware-configuration.nix` content
   - `disko.nix` - Configure disk layout (update device paths!)

3. **Build:**
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

Required files:
- `default.nix` - Host configuration and domain enables
- `hardware.nix` - Hardware-specific settings
- `disko.nix` - Declarative disk partitioning

### Adding a New User

1. **Copy template:**
   ```bash
   cp -r compositions/users/max compositions/users/<username>
   ```

2. **Edit:**
   - `default.nix` - System-level user config (UID, groups, shell, hashedPasswordFile)
   - `home.nix` - Home Manager config (packages, dotfiles)

3. **Add user to host's hostUsers list:**
   ```nix
   # In compositions/hosts/<hostname>/default.nix:
   hostUsers = [ "<username>" ];
   ```

For host-specific user config, create:
- `compositions/users/<username>/hosts/<hostname>.nix`

### Adding a New Domain Module

1. **Create module file:**
   ```bash
   # Either create a standalone file:
   touch domains/<category>/<feature>.nix

   # Or create a directory with default.nix:
   mkdir -p domains/<category>/<feature>
   touch domains/<category>/<feature>/default.nix
   ```

2. **Define options under domains namespace:**
   ```nix
   options.domains.<category>.<feature> = {
     enable = mkEnableOption "My feature";  # If Capability domain
     # ... more options
   };
   ```

3. **Implement config:**
   ```nix
   config = mkIf cfg.enable {  # If Capability
     # ... implementation
   };
   ```

The module is **automatically imported** - no changes to `flake.nix` needed.

## Debugging

### Check What's Being Discovered

```bash
# List all discovered hosts
nix eval .#lib.listHostNames

# List all discovered domain module paths
nix eval .#lib.domainModulePaths
```

### Evaluate Host Configuration

```bash
# See the full evaluated config for a host
nix eval .#nixosConfigurations.odysseus.config.system.build.toplevel
```

### Trace Module Imports

```bash
# Show which modules are being loaded
nix-instantiate --eval --strict --expr '
  with import <nixpkgs> {};
  (import ./lib/default.nix { inherit lib; }).mkHostModules "odysseus" []
'
```

## Testing

### Test in VM

```bash
# Build VM for testing
nixos-rebuild build-vm --flake .#<hostname>

# Run the VM (created in ./result/bin/)
./result/bin/run-nixos-vm
```

### Test Specific Module

```bash
# Evaluate just a specific module
nix eval .#nixosConfigurations.<hostname>.config.domains.<category>.<feature>
```

## Common Workflows

### Updating Flake Inputs

```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
nix flake lock --update-input home-manager
```

### Cleaning Up

```bash
# Remove old generations (if using nh.clean)
sudo nh clean all --keep 5 --keep-since 7d

# Manual garbage collection
sudo nix-collect-garbage --delete-older-than 30d

# Full cleanup with store optimization
sudo nix-collect-garbage -d
sudo nix-store --optimize
```

### Checking Disk Usage

```bash
# Check Nix store size
du -sh /nix/store

# List largest store paths
nix path-info --recursive --size --closure-size /run/current-system | sort -k2 -h
```
