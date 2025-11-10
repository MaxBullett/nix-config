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

    # Install custom CA certificates at runtime (supports SOPS secrets)
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
        p11-kit
      ];
      script = ''
        set -euo pipefail

        # p11-kit looks for certificates in /etc/pki/trust/source/anchors on NixOS
        CERT_DIR="/etc/pki/trust/source/anchors"
        mkdir -p "$CERT_DIR"

        ${concatMapStringsSep "\n" (certPath: ''
          if [ -f "${certPath}" ]; then
            CERT_NAME="$(basename "${certPath}")"
            cp -f "${certPath}" "$CERT_DIR/$CERT_NAME"
            echo "Installed certificate: $CERT_NAME"
          else
            echo "Warning: Certificate file not found: ${certPath}" >&2
          fi
        '') cfg.certificatePaths}

        # Rebuild system trust store with new certificates
        ${pkgs.p11-kit}/bin/trust extract-compat
        echo "System trust store updated successfully"
      '';
    };
  };
}
