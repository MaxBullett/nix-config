{
  config,
  inputs,
  ...
}:
let
  userName = "max";
  secretKey = "passwords/${userName}";
in
{
  home-manager.users.${userName} = import ./home.nix;

  sops = {
    secrets."${secretKey}" = {
      sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
      neededForUsers = true;
    };
  };

  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPasswordFile = config.sops.secrets."${secretKey}".path;
  };
}
