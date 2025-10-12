{
  config,
  hostUsers ? [ ],
  hostName,
  lib,
  pkgs,
  ...
}:
let
  allUsers = hostUsers ++ [ "root" ];
in
{
  # Import common and host-specific user configurations
  imports =
    let
      userImports =
        name:
        lib.filter lib.pathExists (
          map lib.custom.relativeToRoot [
            "users/${name}/default.nix"
            "users/${name}/${hostName}.nix"
          ]
        );
    in
    lib.flatten (map userImports allUsers);

  config = lib.mkMerge [
    # Declare sops users secrets
    {
      sops.secrets =
        let
          secrets = user: [
            {
              name = "${hostName}/passwords/${user}";
              value = {
                sopsFile = config.sops.defaultSopsFile;
                format = "yaml";
                key = "${hostName}.passwords.${user}";
                owner = "root";
                mode = "0400";
              };
            }
          ];
        in
        lib.listToAttrs (lib.concatMap secrets allUsers);
    }

    # Generate all users
    {
      users = {
        mutableUsers = false;
        users =
          let
            mkUser = user: {
              isNormalUser = lib.mkIf (user != "root") true;
              home = lib.mkIf (user != "root") "/home/${user}";
              shell = lib.mkIf (user != "root") (lib.mkDefault pkgs.zsh);
              hashedPasswordFile = lib.mkDefault config.sops.secrets."${hostName}/passwords/${user}".path;
            };
          in
          lib.genAttrs allUsers mkUser;
      };
    }
  ];
}
