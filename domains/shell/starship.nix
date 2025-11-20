{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    literalExpression
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.shell.starship.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  starshipHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.shell.starship;
    in
    {
      options.domains.shell.starship = {
        enable = mkEnableOption "starship prompt";

        settings = mkOption {
          type = types.attrs;
          default = { };
          description = ''
            Configuration options for starship prompt.
            This uses starship's native default configuration.
            See <https://starship.rs/config/> for available options.
            Example:
              {
                add_newline = true;
                character = {
                  success_symbol = "[➜](bold green)";
                  error_symbol = "[✗](bold red)";
                };
                directory = {
                  truncation_length = 3;
                  truncate_to_repo = true;
                };
              }
          '';
          example = literalExpression ''
            {
              add_newline = true;
              command_timeout = 500;

              format = lib.concatStrings [
                "$username"
                "$hostname"
                "$directory"
                "$git_branch"
                "$git_status"
                "$character"
              ];

              character = {
                success_symbol = "[➜](bold green)";
                error_symbol = "[✗](bold red)";
                vicmd_symbol = "[❮](bold green)";
              };

              directory = {
                style = "cyan bold";
                truncation_length = 3;
                truncate_to_repo = true;
              };

              git_branch = {
                symbol = " ";
                style = "bold purple";
              };

              git_status = {
                style = "red bold";
                disabled = false;
              };

              nix_shell = {
                symbol = " ";
                style = "bold blue";
              };
            }
          '';
        };
      };

      config = mkIf cfg.enable {
        programs.starship = {
          enable = true;
          inherit (cfg) settings;
          enableNushellIntegration = config.domains.shell.nushell.enable or false;
        };

        # Install starship in home.packages to ensure it's available when nushell starts
        home.packages = [ pkgs.starship ];
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ starshipHomeModule ];
    }

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".cache/starship"
          ];
        }) enabledUsers;
      };
    })
  ];
}
