# nix-config Migration TODO

This document tracks the migration from lachesis to nix-config and additional features to implement.

## Current Status (Updated Nov 14, 2024)

### 🎉 Ready for Deployment!

**All essential functionality has been migrated from lachesis to nix-config.**

**Critical Remaining Task:**
- 🔴 **Deploy and test** on odysseus system

**What's Complete:**
- ✅ All security & system domains (sops, pki, doas, ssh, gnome-keyring, etc.)
- ✅ All hardware & peripherals (firmware, sensors, power management)
- ✅ All networking services (NetworkManager, avahi, bluetooth)
- ✅ Storage & backups (btrfs preservation, btrbk snapshots, restic remote backup)
- ✅ All applications (Steam, Flatpak w/ Stremio, OBS Studio, Firefox, JetBrains IDEs, etc.)
- ✅ All critical user persistence paths auto-managed by domains
- ✅ 45+ domain modules with DDD-compliant architecture

**Optional Post-Migration Tasks:**
- 🟢 Stylix theming research
- 📋 Documentation improvements

---

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

## Phase 2: Hardware & Peripherals ✅ COMPLETE

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

## Phase 5: Applications ✅ COMPLETE

- [x] **domains/applications/steam.nix** - Gaming platform (Hybrid)
  - ✅ Fully implemented with hybrid pattern
  - System-level Steam with gamemode
  - Per-user enable via home-manager
  - Automatic persistence: `.local/share/Steam`, `.steam`
  - Proton GE support enabled in max user config

- [x] **domains/applications/flatpak.nix** - Flatpak support
  - ✅ Declarative package management via systemd service
  - Supports both flathub and flathub-beta remotes
  - Simple `packages` and `betaPackages` options
  - Automatic remote setup and package installation
  - Full persistence: `/var/lib/flatpak`, `.local/share/flatpak`, `.var/app`
  - Stremio 5 installed from flathub-beta

- [x] **domains/applications/obs-studio.nix** - Screen recording (Hybrid)
  - ✅ Fully implemented with default plugin set from lachesis
  - Virtual camera support (enabled for max)
  - Plugins: wlrobs, backgroundremoval, pipewire, vaapi, gstreamer, vkcapture
  - Automatic persistence: `.config/obs-studio`
  - Hardware acceleration enabled

---

## Phase 6: User Environment ✅ COMPLETE

### User Persistence - Auto-Handled by Domains ✅

All critical user persistence paths are now automatically handled by their respective domains:

- [x] `.ssh` → **ssh domain** (auto-persists for all normal users)
- [x] `.config/git` → **git domain** (auto-persists when git enabled)
- [x] `.config/gh` → **github-cli domain** (auto-persists when gh enabled)
- [x] `.claude` → **claude-code domain** (auto-persists when enabled)
- [x] `.config/cosmic`, `.local/state/cosmic*` → **cosmic domain** (auto-persists)
- [x] `.local/share/keyrings` → **gnome-keyring domain** (auto-persists)
- [x] `.mozilla` → **firefox domain** (auto-persists to /preserve)
- [x] `.config/JetBrains`, `.cache/JetBrains`, `.local/share/JetBrains` → **jetbrains domain**
- [x] `.java/.userPrefs` → **jetbrains domain** (added Nov 2024)
- [x] `.config/sops` → **sops domain** (added Nov 2024)
- [x] `.local/share/flatpak`, `.var/app` → **flatpak domain** (added Nov 2024)
- [x] ~~`.gnupg`~~ → **NOT NEEDED** (using SSH signing for git, not GPG)
- [x] ~~`.local/share/zsh`~~ → **NOT NEEDED** (migrated to nushell)

### User Packages - Auto-Handled by Domains ✅

- [x] `claude-code` → **claude-code domain**
- [x] `jetbrains.dataspell`, `jetbrains.idea-ultimate` → **jetbrains domain**
- [x] `ripgrep` → **ripgrep domain** (added Nov 2024)
- [x] ~~`borgbackup`~~ → **NOT NEEDED** (using btrbk + restic for snapshots)
- [x] ~~`fd`, `rclone`, `unzip`, `u-root`~~ → **NOT NEEDED** (not essential)

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
   - pki, doas, ssh, sops, gnome-keyring, time-sync, zram, journald
   - Note: rtkit handled by pipewire, polkit handled by cosmic
   - Recent additions: sops user age key persistence (Nov 2024)
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
5. ✅ **Applications** (Steam, Flatpak, OBS Studio) - COMPLETE
   - steam domain fully implemented with hybrid pattern
   - flatpak domain with declarative package management
   - obs-studio domain with full plugin support
6. ✅ **User Environment** (all critical paths handled by domains) - COMPLETE
   - All user persistence auto-managed by respective domains
   - Recent additions: ripgrep domain, jetbrains Java prefs (Nov 2024)
7. 🟢 **Theming** (stylix research) - OPTIONAL
   - Low priority, can be done post-migration
8. 📋 **Documentation** (2 tasks) - OPTIONAL
   - Nice to have, not blocking migration
9. 🔴 **Testing** (deployment test) - CRITICAL REMAINING TASK

### Migration Progress (Updated Nov 14, 2024)
- ✅ **ALL lachesis functionality migrated - 100% feature parity!**
- ✅ **All critical user persistence handled by domains**
- ✅ Phases 1-6 complete (all core functionality)
- ✅ 45+ domain modules implemented with auto-persistence
- ✅ All applications from lachesis now in domains (Steam, Flatpak, OBS Studio)
- ✅ Architecture docs updated (one-way dependencies clarified)
- ✅ 100% DDD compliance verified
- 🔴 **READY FOR DEPLOYMENT TESTING**
- 📦 Optional tasks remaining: stylix theming, documentation
