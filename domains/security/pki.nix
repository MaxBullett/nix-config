{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatMapStringsSep
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.domains.security.pki;
in
{
  options.domains.security.pki = {
    enable = mkEnableOption "custom CA certificate management";

    certificatePaths = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        Paths to CA certificate files to trust system-wide.
        These paths are evaluated at runtime, making them suitable for
        SOPS secrets or other dynamically-provisioned certificate sources.
        Certificates will be added to the system trust store and trusted by
        all applications (browsers, curl, openssl, etc.).
      '';
      example = [
        config.sops.secrets."ca-certs/domain".path
      ];
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.certificatePaths != [ ];
        message = "domains.security.pki.certificatePaths must not be empty when enabled";
      }
    ];

    systemd.services.install-custom-ca-certs = {
      description = "Install custom CA certificates to system trust store";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-install-secrets.service" ];
      wants = [ "sops-install-secrets.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        coreutils
        openssl
      ];
      script = ''
        set -euo pipefail

        # On NixOS, we need to add certificates to /etc/ssl/certs manually
        CERT_DIR="/etc/ssl/certs"

        ${concatMapStringsSep "\n" (certPath: ''
          if [ -f "${certPath}" ]; then
            CERT_NAME="$(basename "${certPath}")"
            # Copy certificate
            cp -f "${certPath}" "$CERT_DIR/$CERT_NAME"

            # Create hash-based symlink for OpenSSL compatibility
            HASH=$(openssl x509 -noout -hash -in "${certPath}" 2>/dev/null || echo "")
            if [ -n "$HASH" ]; then
              # Find next available .N suffix
              SUFFIX=0
              while [ -L "$CERT_DIR/$HASH.$SUFFIX" ] || [ -f "$CERT_DIR/$HASH.$SUFFIX" ]; do
                SUFFIX=$((SUFFIX + 1))
              done
              ln -sf "$CERT_NAME" "$CERT_DIR/$HASH.$SUFFIX"
              echo "Installed certificate: $CERT_NAME (hash: $HASH.$SUFFIX)"
            else
              echo "Warning: Could not compute hash for ${certPath}, skipping symlink" >&2
            fi
          else
            echo "Warning: Certificate file not found: ${certPath}" >&2
          fi
        '') cfg.certificatePaths}

        echo "Custom CA certificates installed successfully"
      '';
    };
  };
}
