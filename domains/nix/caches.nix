{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.domains.nix.caches;

  cacheType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
        description = "URL of the binary cache.";
        example = "https://your-cache.cachix.org";
      };

      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public key for this cache. If null, the cache is not trusted.";
        example = "your-cache.cachix.org-1:abcd1234...";
      };
    };
  };

  defaultCaches = [
    {
      url = "https://nix-community.cachix.org";
      key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    }
  ];

  allCaches = defaultCaches ++ cfg.extraCaches;
in
{
  options.domains.nix.caches = {
    extraCaches = mkOption {
      type = types.listOf cacheType;
      default = [ ];
      description = "Additional binary caches beyond the defaults (nix-community).";
      example = lib.literalExpression ''
        [
          {
            url = "https://your-cache.cachix.org";
            key = "your-cache.cachix.org-1:abcd1234...";
          }
        ]
      '';
    };

    require-sigs = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Require cryptographic signatures on binary cache packages.
        Setting to false allows unsigned caches (security risk!).
      '';
    };

    push = {
      enable = mkEnableOption ''
        automatic pushing of unique builds to personal cachix.
        Only pushes paths not found in public caches to save space
      '';

      cacheName = mkOption {
        type = types.str;
        description = "Name of your cachix cache to push to.";
        example = "maxbullett";
      };

      tokenFile = mkOption {
        type = types.str;
        description = ''
          Path to file containing cachix auth token.
          The host must provide this path (e.g., from sops, agenix, or a plain file).
        '';
        example = "/run/secrets/cachix-token";
      };

      skipCaches = mkOption {
        type = types.listOf types.str;
        default = [ "https://cache.nixos.org" ] ++ (map (cache: cache.url) allCaches);
        defaultText = lib.literalExpression ''[ "https://cache.nixos.org" ] ++ (all configured caches)'';
        description = ''
          Don't push paths that exist in these caches.
          Defaults to all configured caches plus cache.nixos.org.
        '';
      };
    };
  };

  config = mkMerge [
    {
      nix.settings = {
        substituters = map (cache: cache.url) allCaches;
        trusted-public-keys = lib.filter (key: key != null) (map (cache: cache.key) allCaches);
        inherit (cfg) require-sigs;
      };
    }

    (mkIf cfg.push.enable {
      assertions = [
        {
          assertion = cfg.push.tokenFile != "";
          message = "domains.nix.caches.push.tokenFile must be set";
        }
        {
          assertion = cfg.push.cacheName != "";
          message = "domains.nix.caches.push.cacheName must be set";
        }
      ];

      nix.settings.post-build-hook = pkgs.writeShellScript "cachix-push-smart" ''
        set -euo pipefail
        export PATH="${
          lib.makeBinPath [
            pkgs.cachix
            pkgs.nix
          ]
        }"

        # Read cachix token
        export CACHIX_AUTH_TOKEN="$(cat ${lib.escapeShellArg cfg.push.tokenFile})"

        # Skip caches to check
        skip_caches=(${lib.concatMapStringsSep " " lib.escapeShellArg cfg.push.skipCaches})

        echo "post-build-hook: Checking built paths for uniqueness..."

        # For each built path
        for out_path in $OUT_PATHS; do
          found=false

          # Get all dependencies (thorough check)
          echo "  Checking $out_path and its dependencies..."
          deps=$(nix-store --query --requisites "$out_path" || echo "")

          if [ -z "$deps" ]; then
            echo "  Warning: Could not query dependencies for $out_path"
            continue
          fi

          # Check if any dependency exists in skip caches
          for dep in $deps; do
            for cache in "''${skip_caches[@]}"; do
              if nix path-info --store "$cache" "$dep" &>/dev/null; then
                echo "  Found dependency $dep in $cache, skipping push"
                found=true
                break 2
              fi
            done
          done

          # Only push if not found in any skip cache
          if [ "$found" = false ]; then
            echo "  Path $out_path is unique! Pushing to ${cfg.push.cacheName}..."
            cachix push ${lib.escapeShellArg cfg.push.cacheName} "$out_path"
            echo "  Successfully pushed $out_path"
          fi
        done

        echo "post-build-hook: Complete"
      '';
    })
  ];
}
