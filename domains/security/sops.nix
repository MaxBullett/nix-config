{
  lib,
  inputs,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  cfg = config.domains.security.sops;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.domains.security.sops = {
    enable = mkEnableOption "sops-nix integration for host and user secrets";

    sshKeyPaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Age identities (SSH private keys) to consider for decryption.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sshKeyPaths != [ ];
        message = "domains.security.sops.sshKeyPaths must not be empty (required for decryption)";
      }
    ];

    sops = {
      defaultSopsFile = "${inputs.nix-secrets}/hosts/${config.networking.hostName}/secrets.yaml";
      validateSopsFiles = true;
      age = {
        inherit (cfg) sshKeyPaths;
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = true;
      };
    };
  };
}
