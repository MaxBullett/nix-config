# Nix Secrets Stub

This directory contains placeholder secret files used by GitHub Actions for CI/CD builds.

## Purpose

The main nix-config repository references a private `nix-secrets` repository via flake inputs. Since GitHub Actions doesn't have SSH access to the private repository, we provide stub files here to allow the configuration to evaluate and build in CI.

## Structure

```
.github/nix-secrets-stub/
├── hosts/
│   └── odysseus/
│       └── secrets.yaml  # Stub host secrets
└── users/
    └── max/
        └── secrets.yaml  # Stub user secrets
```

## Important Notes

- These are **placeholder files only** - they contain no real secrets
- Actual secrets are stored in the private `nix-secrets` repository
- CI builds use `--override-input nix-secrets` to replace the private repo with this stub
- Real deployments still use the actual private secrets repository
