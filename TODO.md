# nix-config Migration TODO

This document tracks the migration from lachesis to nix-config and additional features to implement.

## Legend
- 🔴 High Priority - Core functionality, security-critical
- 🟡 Medium Priority - Quality of life, non-critical features
- 🟢 Low Priority - Nice to have, polish
- 📋 Documentation/Research task

---

## Phase 1: Critical Security & Core System ✅ COMPLETE

### Security Domains ✅

- [x] **domains/security/pki.nix** - Custom CA certificates
  - Uses `certificateFiles` for runtime sops secret paths
  - Configured in odysseus with daadev CA cert
  - Clean assertions and documentation

- [x] **domains/security/doas.nix** - Sudo replacement
  - Aligned option names (wheel.noPass, wheel.persist, wheel.keepEnv)
  - Power commands option (enabled in odysseus)
  - Automatic sudo wrapper (always enabled)
  - Clean inherit pattern

- [x] **domains/security/ssh.nix** - SSH client module
  - Connection keep-alive (60s default)
  - Connection multiplexing (enabled in odysseus)
  - Agent forwarding control (disabled by default)
  - Automatic .ssh persistence for all normal users

- [x] **domains/security/gnome-keyring.nix** - Secrets management (Hybrid)
  - Auto-detects COSMIC greeter for PAM integration
  - Optional SSH agent and Seahorse GUI
  - Automatic keyring persistence for all normal users
  - System service + PAM + per-user pattern

- [x] ~~**domains/security/polkit.nix**~~ - Already handled by cosmic.nix
- [x] ~~**domains/security/rtkit.nix**~~ - Already handled by pipewire.nix

### System Fundamentals ✅

- [x] **domains/system/time-sync.nix** - Time synchronization
  - NTP with timesyncd
  - Configurable servers (Cloudflare + pool.ntp.org defaults)
  - Uses inherit pattern

- [x] **domains/system/zram.nix** - Memory compression
  - 10% of RAM default
  - Configurable memoryPercent and priority
  - Uses inherit pattern

- [x] **domains/system/journald.nix** - Journal configuration
  - Smart storage default (persistent when preservation enabled)
  - Automatic /var/log persistence when storage=persistent
  - MaxSize (1G default), MaxRetentionSec, MaxFileSec options
  - Couples storage mode with preservation (excellent DDD pattern)

---

## Phase 2: Hardware & Peripherals 🔴

### Hardware Management

- [x] **domains/hardware/firmware.nix** - Firmware updates (fwupd)
  - Extract from lachesis: `services.fwupd.enable = true`
  - First verify nixos-hardware doesn't already enable this
  - Check: `nixos-hardware.nixosModules.asus-zephyrus-ga402`

- ~~[ ] **domains/hardware/thunderbolt.nix**~~ - Not relevant

- [x] **domains/hardware/sensors.nix** - Hardware monitoring
  - Extract from lachesis: `environment.systemPackages = [ pkgs.lm_sensors ]`
  - Could also enable kernel modules if needed
  - Allows monitoring temps, fans, voltages

### Hardware-Specific (odysseus/hardware.nix)

These are specific to the ASUS Zephyrus GA402RK and should live in `compositions/hosts/odysseus/hardware.nix`:

- [x] **Sleep configuration** - s2idle suspend mode
  - Extract from lachesis:
    ```nix
    systemd.sleep.extraConfig = ''
      SuspendState=mem
      SuspendMode=
    '';
    ```
  - GA402RK uses s2idle; don't force "deep" sleep

- [x] **ASUSD persistence**
  - ✅ Added to odysseus host persistence: `/etc/asusd`
  - nixos-hardware already enables asusd service

---

## Phase 3: Storage & Maintenance ✅ COMPLETE

- [x] **domains/storage/btrfs/scrub.nix** - Filesystem maintenance
  - ✅ Already implemented in btrfs/default.nix
  - autoScrub with configurable interval (weekly default)
  - Auto-detects all btrfs filesystems

- [x] **domains/storage/btrfs/snapshots.nix** - Backup via snapshots
  - ✅ Implemented with btrbk + restic approach
  - btrbk for local snapshots (7d 4w retention)
  - restic for remote B2 backups (7d 4w 12m 1y retention)
  - End-to-end encryption with age/restic
  - Content-addressed deduplication (no chain dependencies!)
  - Setup documentation in SNAPSHOTS-SETUP.md
  - Secrets required: restic-password, restic-b2-env (via sops)

- [x] **Audit system persistence paths** - Missing directories
  - Compare lachesis vs nix-config odysseus host
  - Missing from nix-config:
    - `/etc/asusd` (ASUS daemon config)
    - `/var/lib/cups` (printer config)
    - `/var/cache/cups` (printer cache)
  - Review if these should be added to domains or host config

---

## Phase 4: Networking & Services ✅ COMPLETE

- [x] **domains/networking/avahi.nix** - mDNS/Zeroconf
  - ✅ Implemented with auto-persistence
  - Configurable nssmdns and openFirewall options (both default true)
  - Discovers printers, NAS, and other .local services
  - Automatically persists `/var/lib/avahi-daemon`

- [x] **LC3 support** - LE Audio
  - ✅ Already enabled via bluetooth `General.Experimental = true`
  - Bluetooth LE Audio with LC3 codec works out of the box
  - No additional wireplumber configuration needed

---

## Phase 5: Applications 🟡

- [x] **domains/applications/steam.nix** - Gaming platform (Hybrid)
  - Follow firefox hybrid pattern (system + per-user)
  - Extract from lachesis steam system module:
    - `programs.steam.enable = true`
    - `programs.steam.remotePlay.openFirewall = true`
    - `programs.steam.dedicatedServer.openFirewall = true`
    - `programs.gamemode.enable = true`
    - Custom proton-ge-bin package
  - Per-user enable via home-manager
  - Persistence (per-user): `.local/share/Steam`, `.steam`
  - Uses `anyUser` pattern: enables if any home-manager user wants it

- [ ] **domains/applications/flatpak.nix** - Flatpak support
  - Extract from lachesis: `services.flatpak.enable = true`
  - System persistence: `/var/lib/flatpak`
  - User persistence (per-user): `.local/share/flatpak`, `.var/app`
  - Simple enable module

- [ ] **domains/applications/obs-studio.nix** - Screen recording (Hybrid)
  - Extract from lachesis:
    - `programs.obs-studio.enable = true`
    - `programs.obs-studio.enableVirtualCamera = true`
    - Extensive plugin list (wlrobs, backgroundremoval, pipewire, vaapi, etc.)
  - Hybrid: system packages + per-user config/plugins
  - May want user-level plugin selection

---

## Phase 6: User Environment 🟢

- [ ] **Audit user persistence paths** - Missing directories
  - Compare lachesis max user vs nix-config max user
  - Missing from nix-config (lachesis has in persist):
    - `.gnupg` (GPG keys)
    - `.claude` (Claude Code state)
    - `.local/share/zsh` (shell history - though switching to nushell)
    - `.config/cosmic`, `.local/state/cosmic*` (COSMIC settings)
    - `.local/share/keyrings` (gnome-keyring - critical!)
    - `.mozilla` (Firefox - but now using domain persistence)
    - `.config/JetBrains`, `.cache/JetBrains`, `.local/share/JetBrains`
    - `.java/.userPrefs`
    - `.config/sops` (SOPS age keys)
    - `.local/share/flatpak`, `.var/app` (user flatpak apps)
    - `.config/cosmic-initial-setup-done` (file)
  - Some may now be handled by hybrid domains (Firefox, COSMIC)
  - Need to reconcile and update max user config

- [ ] **Add missing packages to max user**
  - Currently has: htop, jq
  - Missing from lachesis:
    - `borgbackup` (backup tool - until snapshot strategy ready)
    - `fd` (modern find)
    - `rclone` (cloud storage sync)
    - `ripgrep` (modern grep)
    - `unzip` (archive utility)
    - `u-root` (Go-based userspace tools)
    - `claude-code` (already have this)
    - JetBrains IDEs:
      - `jetbrains.dataspell` (Python data science IDE)
      - `jetbrains.idea-ultimate` (Java IDE)
  - Add to: `compositions/users/max/default.nix` in `home.packages`

- [ ] **domains/applications/borgbackup.nix** - Backup management (optional) 📋
  - Current approach: manual borgbackup in user packages
  - Domain approach: declarative backup configuration
  - May be superseded by btrfs snapshot strategy
  - Low priority: can just use borgbackup from packages for now

---

## Phase 7: Theming & Polish 🟢

- [ ] **Research stylix integration** 📋
  - Stylix: System-wide theming using base16 color schemes
  - Replaces manual Catppuccin configuration
  - Research:
    - How stylix works with NixOS + Home Manager
    - Integration with COSMIC (may not be supported yet)
    - How to structure in DDD architecture
    - Whether to use as domain or direct integration
  - Document findings in `docs/theming.md`
  - Potential module: `domains/desktop/stylix.nix` or direct home-manager usage

---

## Phase 8: Documentation 📋

- [ ] **Add nixos-hardware integration pattern to documentation**
  - Document best practice for hardware module imports
  - Current pattern: import in `compositions/hosts/<hostname>/hardware.nix`
  - Example: `inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402`
  - Add to: `docs/patterns.md` under "Hardware-specific configuration"

- [ ] **Document hybrid domain pattern improvements** 📋
  - Document gnome-keyring as reference hybrid module
  - Show PAM integration pattern
  - Show system service + user config pattern
  - Add to: `docs/patterns.md`

---

## Phase 9: Testing & Finalization 🔴

- [ ] **Test full nix-config deployment on odysseus**
  - Build configuration: `nix flake check`
  - Test build: `nixos-rebuild build --flake .#odysseus`
  - Dry run: `nixos-rebuild dry-activate --flake .#odysseus`
  - Full switch: `sudo nixos-rebuild switch --flake .#odysseus`
  - Verify all services start correctly
  - Test reboot with ephemeral root

- [ ] **Archive lachesis repository**
  - Once migration fully verified and tested
  - Create final commit documenting completion
  - Archive repository on GitHub
  - Update README to point to nix-config

---

## Notes

### Design Decisions
- **SSH + PKI**: Separate modules for better DDD bounded contexts
- **Time-sync**: Separate from localization (independent concern)
- **Gnome-keyring**: Needed for COSMIC (no native secrets management yet)
- **Hardware-specific**: Keep in hardware.nix unless generic/large enough for domain

### Backup Strategy Evolution
```
Current:  borgbackup (manual, in user packages)
          ↓
Future:   btrfs snapshots of @preserve subvolume
          → Research btrbk, snapper, or custom solution
          → Automatic periodic snapshots
          → Off-site replication strategy
```

### Module Priorities by Phase
1. ✅ **Security + System** (7 modules) - COMPLETE
   - pki, doas, ssh, gnome-keyring, time-sync, zram, journald
   - Note: rtkit handled by pipewire, polkit handled by cosmic
2. ✅ **Hardware** (2 modules + hardware.nix + asusd persistence) - COMPLETE
   - firmware, sensors, hardware-specific sleep config, asusd persistence
   - Note: thunderbolt not needed (GA402RK has USB4, not Thunderbolt)
   - Note: asusd service provided by nixos-hardware
3. ✅ **Storage** (snapshots + scrub) - COMPLETE
   - btrfs scrub already in default.nix
   - snapshots implemented with btrbk + restic
4. ✅ **Networking** (1 module + LC3 verified) - COMPLETE
   - avahi for mDNS/Zeroconf service discovery
   - LC3 already works via bluetooth.settings.General.Experimental
5. ⏳ **Applications** (3 modules) - Pending
6. ⏳ **User Environment** (audit + packages) - Pending
7. ⏳ **Theming** (research) - Pending
8. ⏳ **Documentation** (2 tasks) - Pending
9. ⏳ **Testing** (2 tasks) - Pending

### Migration Progress
- ✅ 14/15 lachesis modules migrated (only steam remaining)
- ✅ rtkit + polkit already handled (pipewire + cosmic)
- ✅ Phase 1 complete: 7 modules (security + system)
- ✅ Phase 2 complete: 2 modules + hardware config (hardware)
- ✅ Phase 3 complete: 1 module + scrub verification (storage)
- ✅ Phase 4 complete: 1 module + LC3 verification (networking)
- ✅ Architecture docs updated (one-way dependencies clarified)
- ✅ 100% DDD compliance verified
- 📦 ~9 tasks remaining (phases 5-9)
