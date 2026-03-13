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
        Certificates will be installed into the p11-kit trust anchor store
        and trusted by all applications (browsers, curl, openssl, etc.).
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
      description = "Install custom CA certificates into system trust stores";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-install-secrets.service" ];
      wants = [ "sops-install-secrets.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        coreutils
        nss.tools
      ];
      script = ''
        set -euo pipefail

        # System NSS database (read by Chromium/Vivaldi)
        NSS_DB="/etc/pki/nssdb"
        mkdir -p "$NSS_DB"
        if [ ! -f "$NSS_DB/cert9.db" ]; then
          certutil -N -d "sql:$NSS_DB" --empty-password
        fi

        # Extend system CA bundle for curl/openssl/etc
        CUSTOM_BUNDLE="/etc/ssl/certs/ca-bundle-custom.crt"
        cp -f "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" "$CUSTOM_BUNDLE"
        chmod 644 "$CUSTOM_BUNDLE"

        ${concatMapStringsSep "\n" (certPath: ''
          if [ -f "${certPath}" ]; then
            CERT_NAME="$(basename "${certPath}")"

            # Add to system NSS database for Chromium/Vivaldi
            certutil -A -d "sql:$NSS_DB" -n "$CERT_NAME" -t "CT,," -i "${certPath}"
            echo "Added to NSS database: $CERT_NAME"

            # Append to CA bundle for curl/openssl
            cat "${certPath}" >> "$CUSTOM_BUNDLE"
            echo "Appended to CA bundle: $CERT_NAME"
          else
            echo "Error: Certificate file not found: ${certPath}" >&2
            exit 1
          fi
        '') cfg.certificatePaths}

        ln -sf ca-bundle-custom.crt /etc/ssl/certs/ca-certificates.crt
      '';
    };

    environment.sessionVariables = {
      SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle-custom.crt";
      CURL_CA_BUNDLE = "/etc/ssl/certs/ca-bundle-custom.crt";
      NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-bundle-custom.crt";
    };
  };
}
