{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;
  cfg = config.domains.audio.pipewire;

  # Find all normal users (PipeWire runs per-user)
  normalUsers = filterAttrs (_: user: user.isNormalUser or false) config.users.users;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;
in
{
  options.domains.audio.pipewire = {
    enable = mkEnableOption "PipeWire audio system";

    alsa = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable ALSA support.";
      };

      support32Bit = mkOption {
        type = types.bool;
        default = true;
        description = "Enable 32-bit ALSA support for compatibility.";
      };
    };

    pulse.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable PulseAudio compatibility layer.";
    };

    wireplumber.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable WirePlumber session manager.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.pipewire = {
        enable = true;
        inherit (cfg) alsa pulse wireplumber;
      };

      # Required for real-time audio scheduling
      security.rtkit.enable = true;
    })

    # Conditional persistence for all normal users
    (mkIf (cfg.enable && cfg.wireplumber.enable && preservationEnabled) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            # WirePlumber state (device preferences, routing rules, per-app volumes)
            ".local/state/wireplumber"
          ];
        }) normalUsers;
      };
    })
  ];
}
