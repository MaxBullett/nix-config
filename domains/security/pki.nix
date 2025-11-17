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

        CERT_DIR="/etc/ssl/certs"
        CUSTOM_BUNDLE="/etc/ssl/certs/ca-bundle-custom.crt"
        SYSTEM_BUNDLE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

        # Start with the system CA bundle
        cp "$SYSTEM_BUNDLE" "$CUSTOM_BUNDLE"
        chmod 644 "$CUSTOM_BUNDLE"

        # Append each custom certificate to the bundle
        ${concatMapStringsSep "\n" (certPath: ''
          if [ -f "${certPath}" ]; then
            CERT_NAME="$(basename "${certPath}")"

            # Validate it's a proper certificate
            if openssl x509 -noout -text -in "${certPath}" >/dev/null 2>&1; then
              # Copy individual certificate file
              cp -f "${certPath}" "$CERT_DIR/$CERT_NAME"
              chmod 644 "$CERT_DIR/$CERT_NAME"

              # Append to the combined bundle
              echo "" >> "$CUSTOM_BUNDLE"
              cat "${certPath}" >> "$CUSTOM_BUNDLE"

              # Create hash-based symlink for OpenSSL compatibility
              HASH=$(openssl x509 -noout -hash -in "${certPath}")
              SUFFIX=0
              while [ -L "$CERT_DIR/$HASH.$SUFFIX" ] || [ -f "$CERT_DIR/$HASH.$SUFFIX" ]; do
                SUFFIX=$((SUFFIX + 1))
              done
              ln -sf "$CERT_NAME" "$CERT_DIR/$HASH.$SUFFIX"

              echo "Installed certificate: $CERT_NAME (hash: $HASH.$SUFFIX)"
            else
              echo "Error: Invalid certificate file: ${certPath}" >&2
              exit 1
            fi
          else
            echo "Error: Certificate file not found: ${certPath}" >&2
            exit 1
          fi
        '') cfg.certificatePaths}

        # Create symlink for the custom bundle
        ln -sf ca-bundle-custom.crt "$CERT_DIR/ca-certificates.crt"

        echo "Custom CA certificates installed successfully"
        echo "Combined CA bundle created at: $CUSTOM_BUNDLE"
      '';
    };

    # Set environment variables to use the custom CA bundle
    environment.sessionVariables = {
      SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle-custom.crt";
      CURL_CA_BUNDLE = "/etc/ssl/certs/ca-bundle-custom.crt";
      NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-bundle-custom.crt";
    };
  };
}
