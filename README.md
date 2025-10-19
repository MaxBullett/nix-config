# nix-config: A DDD NixOS Flake

## Goals
- **DDD structure**: Separate *domains* (security, storage, lifecycle, UX), *apps* (host & user compositions), and *lib* (composition helpers).
- **Low boilerplate**: One host file + small per‑user files. No global roles.
- **Multi‑host, multi‑user**: Users can be shared across hosts; add host‑specific overlays only when needed.
- **SOPS private repo input**: Provide a dedicated `nix-secrets` flake input.
- **Disko + BTRFS**: Declarative disks with BTRFS subvolumes: `@purge` (ephemeral root), `@persist`, `@preserve`, `@nix`, `@snapshots`.
- **Ephemeral root**: Integrate an external module (e.g. `preservation`) or swap in your own implementation later.
- **Formatting**: `nixfmt-rfc-style` wired via `formatter`.


## Quick start
```bash
# 1) Inspect and edit flake inputs (nix-secrets URL, preservation module path)
# 2) Create your first host
cp -r compositions/hosts/odysseus compositions/hosts/<your-host>
# 3) Create or copy a user
cp -r compositions/users/max compositions/users/<your-user>
# 4) Add your user to the host (see compositions/hosts/<host>/default.nix)
# 5) Build
sudo nixos-rebuild switch --flake .#<your-host>
```


## Add a new host
- Duplicate `compositions/hosts/odysseus` and set:
- `hardware.nix`
- `disko.nix` (device paths!)
- edit `default.nix`: set `hostUsers = [ ... ]` and `networking.hostName`.


## Add a user shared across hosts
- Duplicate `compositions/users/max` to `compositions/users/<name>`.
- Keep shared config in `home.nix` and system‑level config in `default.nix`.
- For host‑specific overrides, create `compositions/users/<name>/hosts/<host>.nix`.


## Secrets
- Secrets live in a **private flake** `nix-secrets` (see `flake.nix`).
- Example layout inside that repo:
- `hosts/<host>/secrets.yaml` (SOPS yaml including `passwords/<user>` key)
- In user modules you’ll see: `sops.secrets."${hostName}/passwords/<user>"`.


## Ephemeral root
- This starter leaves a **TODO** to wire your preferred module. Many teams use a dedicated module (e.g., `preservation`) to recreate `@purge` or snapshot from a seed on boot.
- Subvolumes are created via Disko. Mount points for `@persist` and `@preserve` are declared in the host.


## TODO

- [ ] Testing (bats?)
