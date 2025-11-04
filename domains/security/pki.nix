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

        These are typically provided via sops secrets or other secure sources.
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

    # Add certificate file paths to system trust store
    # Use certificateFiles instead of certificates to support runtime paths (like sops secrets)
    security.pki.certificateFiles = cfg.certificatePaths;
  };
}
