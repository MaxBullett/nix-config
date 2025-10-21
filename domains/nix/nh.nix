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

  cfg = config.domains.nix.nh;
in
{
  options.domains.nix.nh = {
    enable = mkEnableOption "nh CLI helper for Nix and NixOS operations.";

    clean = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable automatic cleanup of old generations and store optimization.
          Note: Conflicts with domains.nix.daemon.gc.automatic - use one or the other.
        '';
      };

      dates = mkOption {
        type = types.str;
        default = "weekly";
        description = "How often to run nh clean (systemd timer format).";
        example = "daily";
      };

      extraArgs = mkOption {
        type = types.str;
        default = "--keep 5 --keep-since 7d";
        description = "Extra arguments passed to nh clean.";
        example = "--keep 10 --keep-since 14d";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.elem "flakes" (config.nix.settings.experimental-features or [ ]);
        message = "domains.nix.nh requires flakes to be enabled (set domains.nix.daemon.flakes = true)";
      }
      {
        assertion = !(cfg.clean.enable && config.nix.gc.automatic);
        message = "domains.nix.nh.clean.enable conflicts with domains.nix.daemon.gc.automatic - disable one";
      }
    ];

    # Enable nh program
    programs.nh = {
      enable = true;

      clean = mkIf cfg.clean.enable {
        enable = true;
        inherit (cfg.clean) dates extraArgs;
      };
    };
  };
}
