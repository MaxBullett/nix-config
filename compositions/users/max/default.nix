{
  config,
  inputs,
  pkgs,
  ...
}:
let
  userName = "max";
  secretKey = "passwords/${userName}";
in
{
  # SOPS secrets for this user
  sops = {
    secrets."${secretKey}" = {
      sopsFile = "${inputs.nix-secrets}/users/${userName}/secrets.yaml";
      neededForUsers = true;
    };
  };

  # System-level user configuration
  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPasswordFile = config.sops.secrets."${secretKey}".path;
  };

  # Home Manager configuration
  home-manager.users.${userName} = {
    # Nushell shell configuration
    domains.shell = {
      nushell = {
        enable = true;
        shellAliases = {
          ll = "ls -l";
          la = "ls -la";
          ".." = "cd ..";
          "..." = "cd ../..";
        };
      };
      starship.enable = true;
    };

    # Home configuration
    home = {
      username = userName;
      homeDirectory = "/home/${userName}";
      packages = with pkgs; [
        htop
        jq
      ];
      stateVersion = "25.05";
    };

    # Git configuration
    programs.git.enable = true;
  };
}
