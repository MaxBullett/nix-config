# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A personal **Domain-Driven Design (DDD) NixOS flake**: reusable capabilities live in
`domains/`, host/user wiring lives in `compositions/`, and both are auto-discovered
(no manual registration in `flake.nix`). Secrets live in a *separate private* flake
(`nix-secrets`, pulled in via SSH) — never in this repo.

Full details are in `docs/`, not repeated here:

| Question | Read |
|---|---|
| How are domains structured, DDD rules, forbidden patterns | `docs/architecture.md` |
| Templates for a new host/user/domain | `docs/patterns.md` |
| How SOPS secrets are wired | `docs/secrets.md` |
| btrbk/restic snapshot & backup setup | `docs/snapshots.md` |
| Build commands, pre-commit, adding hosts/users/domains | `docs/development.md` |
| Common errors and fixes | `docs/troubleshooting.md` |

## Before proposing changes

- Check `docs/architecture.md`'s anti-patterns section first — the most common mistake
  is a domain reaching into another domain (`domains.other.feature = ...`) instead of
  letting the host/user composition wire things together.
- New domain options should mirror the underlying NixOS option name/casing so
  `inherit (cfg) ...` works cleanly — see "Option Naming" in `docs/architecture.md`.
- A missing host/domain is usually a discovery issue (wrong filename/location), not a
  registration issue — see `docs/troubleshooting.md`'s Module Discovery section before
  assuming something needs wiring into `flake.nix`.

## Operational hazards

- `sudo nixos-rebuild switch` (or `nh os switch`) mutates the **live running system**.
  Treat it like any other destructive/hard-to-reverse action — confirm before running it,
  don't run it speculatively "just to check."
- `nixos-rebuild build` / `nh os build` / `build-vm` are safe, non-activating ways to
  verify a change compiles.
- Root (`/`) on hosts using preservation is **ephemeral** (wiped on every boot); only
  paths explicitly listed under `domains.storage.btrfs.preservation.mounts` survive a
  reboot. If something "disappears after reboot," that's expected unless it's persisted.
- Never write secrets (plaintext or otherwise) into this repo — they belong in the
  `nix-secrets` flake, encrypted with SOPS.

## Commands

```bash
nix fmt                    # format all .nix files
nix flake check            # run all checks (deadnix, statix, nixfmt, shellcheck, ...)
nix develop                # dev shell with pre-commit hooks installed
sudo nixos-rebuild switch --flake .#<hostname>   # build + activate (destructive)
nixos-rebuild build --flake .#<hostname>         # build only, safe
```
