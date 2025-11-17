{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  cfg = config.domains.security.sops;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;

  normalUsers = filterAttrs (_: user: user.isNormalUser or false) config.users.users;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.domains.security.sops = {
    enable = mkEnableOption "sops-nix integration for host and user secrets";

    installCli = mkEnableOption "sops CLI tool for encrypting/decrypting secrets";

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

    environment.systemPackages = mkIf cfg.installCli (with pkgs; [ sops ]);

    domains.storage.btrfs.preservation.mounts = mkIf preservationEnabled {
      "/persist".users = mapAttrs (username: _: {
        directories = [
          ".config/sops"
        ];
      }) normalUsers;
    };
  };
}
