{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    mkOption
    types
    ;

  cfg = config.domains.nix.daemon;
in
{
  options.domains.nix.daemon = {
    flakes = mkOption {
      type = types.bool;
      default = true;
      description = "Enable flakes and the unified nix command.";
    };

    auto-optimise-store = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically optimize the Nix store by hard-linking identical files.";
    };

    gc = {
      automatic = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically run garbage collection.";
      };

      dates = mkOption {
        type = types.str;
        default = "weekly";
        description = "How often to run garbage collection (systemd timer format).";
        example = "daily";
      };

      options = mkOption {
        type = types.str;
        default = "--delete-older-than 30d";
        description = "Options passed to nix-collect-garbage.";
        example = "--delete-older-than 14d";
      };
    };

    max-jobs = mkOption {
      type = types.either types.int (types.enum [ "auto" ]);
      default = "auto";
      description = "Maximum number of parallel build jobs. \"auto\" means auto-detect.";
      example = 4;
    };

    cores = mkOption {
      type = types.int;
      default = 0;
      description = "Number of CPU cores to use per build job. 0 means all available cores.";
    };

    builders-use-substitutes = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether remote builders should use binary caches to obtain build dependencies.
        When true, builders check caches before building from source.
        Only relevant if you use remote builders.
      '';
    };

    download-buffer-size = mkOption {
      type = types.int;
      default = 64 * 1024 * 1024; # 64MB
      description = ''
        Size of the buffer used for downloading from binary caches (in bytes).
        Larger values can improve download performance but use more memory.
      '';
    };

    trusted-users = mkOption {
      type = types.listOf types.str;
      default = [
        "root"
        "@wheel"
      ];
      description = "Users trusted to connect to the Nix daemon with elevated privileges.";
    };
  };

  config = {
    nix = {
      package = mkDefault pkgs.nix;

      settings = {
        experimental-features = mkIf cfg.flakes [
          "nix-command"
          "flakes"
        ];

        inherit (cfg)
          auto-optimise-store
          max-jobs
          cores
          builders-use-substitutes
          download-buffer-size
          trusted-users
          ;

        warn-dirty = mkDefault false;
        http-connections = mkDefault 50;
        keep-outputs = true;
        keep-derivations = true;
      };

      gc = mkIf cfg.gc.automatic {
        automatic = true;
        inherit (cfg.gc) dates options;
      };
    };
  };
}
