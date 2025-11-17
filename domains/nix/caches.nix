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

  # Public caches to check (excludes personal cache to avoid redundant checks)
  publicCaches = lib.filter (
    cache: cache.url != "https://${cfg.push.cacheName}.cachix.org"
  ) allCaches;
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
        default = [ "https://cache.nixos.org" ] ++ (map (cache: cache.url) publicCaches);
        defaultText = lib.literalExpression ''[ "https://cache.nixos.org" ] ++ (public caches, excluding personal cache)'';
        description = ''
          Public caches to check before pushing.
          If a path exists in any of these caches, skip pushing (it's already publicly available).
          Defaults to cache.nixos.org and all configured caches except your personal one.
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
        set -eu
        export PATH="${
          lib.makeBinPath [
            pkgs.cachix
            pkgs.nix
            pkgs.coreutils
          ]
        }"

        echo "[$(date)] post-build-hook: Starting..." >&2

        # Validate and read cachix token
        if [ ! -r ${lib.escapeShellArg cfg.push.tokenFile} ]; then
          echo "ERROR: Cannot read token file ${lib.escapeShellArg cfg.push.tokenFile}" >&2
          exit 1
        fi

        export CACHIX_AUTH_TOKEN="$(cat ${lib.escapeShellArg cfg.push.tokenFile})"
        if [ -z "$CACHIX_AUTH_TOKEN" ]; then
          echo "ERROR: Token file is empty!" >&2
          exit 1
        fi

        # Check if OUT_PATHS is set
        if [ -z "''${OUT_PATHS:-}" ]; then
          echo "WARNING: OUT_PATHS is not set, nothing to push" >&2
          exit 0
        fi

        # Public caches to check before pushing
        public_caches=(${lib.concatMapStringsSep " " lib.escapeShellArg cfg.push.skipCaches})

        # For each built path
        for out_path in $OUT_PATHS; do
          found_in_public_cache=false

          # Check if output path exists in any public cache
          for cache in "''${public_caches[@]}"; do
            if timeout 5 nix path-info --store "$cache" "$out_path" &>/dev/null; then
              found_in_public_cache=true
              break
            fi
          done

          # Only push if not found in public caches (means we built it locally)
          if [ "$found_in_public_cache" = false ]; then
            echo "Pushing locally built path to ${cfg.push.cacheName}: $out_path" >&2
            if cachix push ${lib.escapeShellArg cfg.push.cacheName} "$out_path"; then
              echo "Successfully pushed $out_path" >&2
            else
              echo "ERROR: Failed to push $out_path" >&2
            fi
          fi
        done

        echo "[$(date)] post-build-hook: Complete"
      '';
    })
  ];
}
