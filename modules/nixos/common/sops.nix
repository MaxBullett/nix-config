{
  inputs,
  ...
}:
let
  sopsFolder = builtins.toString inputs.nix-secrets;
  secretsFile = "${sopsFolder}/secrets.yaml";
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = "${secretsFile}";
    validateSopsFiles = false;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
  };
}
