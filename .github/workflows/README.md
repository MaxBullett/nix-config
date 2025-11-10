# GitHub Actions Workflows

This directory contains CI/CD workflows for the nix-config repository.

## Secrets Handling in CI

All workflows use `--override-input nix-secrets` to replace the private secrets repository with stub files from `.github/nix-secrets-stub/`. This allows CI builds to succeed without access to the private `nix-secrets` repository.

**Important:** Real deployments still use the actual private secrets repository. The stub is only used for CI validation.

## Workflows

### 1. Build Check (`build.yml`)
**Triggers:** Pull requests, pushes to main

Builds all NixOS configurations to ensure they compile correctly. Catches build errors before deployment.

- Builds each host configuration (odysseus)
- Uses Magic Nix Cache for faster builds
- Fails fast on build errors

### 2. Flake Check (`flake-check.yml`)
**Triggers:** Pull requests, pushes to main

Validates the flake structure and runs all defined checks.

- Runs `nix flake check`
- Validates module imports
- Checks option types and assertions
- Fast syntax/structure validation

### 3. Format Check (`format.yml`)
**Triggers:** Pull requests, pushes to main

Ensures all Nix files are properly formatted using `nixfmt-rfc-style`.

- Checks formatting without modifying files
- Fails if any file needs formatting
- Run `nix fmt` locally to fix formatting issues

### 4. Cachix Push (`cachix.yml`)
**Triggers:** Pushes to main only

Builds configurations and pushes to Cachix binary cache for faster deployments.

- Only runs on main branch (not PRs)
- Requires `CACHIX_AUTH_TOKEN` secret
- Populates `maxbullett` cache

**Setup Required:**
1. Go to repository Settings → Secrets and variables → Actions
2. Add secret `CACHIX_AUTH_TOKEN` with your Cachix token

### 5. Update Flake Inputs (`update-flake.yml`)
**Triggers:** Weekly schedule (Mondays 9 AM UTC), manual dispatch

Automatically updates `flake.lock` and creates a PR.

- Updates all flake inputs weekly
- Runs `nix flake check` to verify updates
- Creates automated PR for review
- Can be triggered manually via Actions tab

### 6. Dead Code Detection (`dead-code.yml`)
**Triggers:** Pull requests, pushes to main, manual dispatch

Scans for unreferenced `.nix` files to help identify dead code.

- Basic static analysis
- May have false positives (files imported via directory)
- Manual review recommended
- Results shown in job summary

## Local Development

Before pushing, you can run checks locally:

```bash
# Check formatting
nix fmt

# Validate flake
nix flake check

# Build configuration
nix build .#nixosConfigurations.odysseus.config.system.build.toplevel
```

## Adding New Hosts

When adding a new host configuration, update the `matrix.host` list in:
- `.github/workflows/build.yml`
- `.github/workflows/cachix.yml`
