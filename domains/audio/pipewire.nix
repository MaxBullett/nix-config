{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.domains.audio.pipewire;
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

  config = mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      inherit (cfg) alsa pulse wireplumber;
    };

    # Required for real-time audio scheduling
    security.rtkit.enable = true;
  };
}
