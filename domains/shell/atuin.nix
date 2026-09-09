{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.shell.atuin.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  atuinHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.shell.atuin;

      nushellEnabled = config.domains.shell.nushell.enable or false;

      # Upstream `atuin init nu` names both the Ctrl-R and the Up-arrow
      # keybinding "atuin"; nushell >= 0.115 warns about keybindings sharing a
      # name on every prompt. Generate the same file ourselves and give each
      # binding a unique name.
      #
      # Fixed upstream in atuin 18.21.0 (atuinsh/atuin#3971, PR #3975); nixpkgs
      # is still on 18.19.0 with the bump open as NixOS/nixpkgs#559134. Drop
      # this and set enableNushellIntegration back to `nushellEnabled` once
      # pkgs.atuin >= 18.21.0.
      atuinNushellInit =
        pkgs.runCommand "atuin-nushell-config.nu"
          {
            nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
          }
          ''
            ${lib.getExe config.programs.atuin.package} init nu > init.nu
            ${lib.getExe pkgs.gnused} \
              -e '0,/name: atuin$/s//name: atuin_ctrl_r/' \
              -e 's/name: atuin$/name: atuin_up_arrow/' \
              init.nu > "$out"
          '';
    in
    {
      options.domains.shell.atuin = {
        enable = mkEnableOption "atuin magical shell history";

        sync = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable atuin sync.";
          };

          keyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Path to the atuin encryption key file (from SOPS).
              If null, you must run 'atuin login' or 'atuin register' manually.
            '';
          };

          sessionFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Path to the atuin session token file (from SOPS).
              If null, you must run 'atuin login' manually.
            '';
          };
        };
      };

      config = mkIf cfg.enable (
        lib.mkMerge [
          {
            programs.atuin = {
              enable = true;
              # Integration is wired up manually below so the generated
              # keybindings can be given unique names.
              enableNushellIntegration = false;

              settings = {
                # Search settings
                search_mode = "fuzzy";
                filter_mode = "global";
                enter_accept = true;

                # Sync settings
                auto_sync = cfg.sync.enable;
                sync_frequency = if cfg.sync.enable then "10m" else "0";
                sync_address = if cfg.sync.enable then "https://api.atuin.sh" else "";

                # UI settings
                dialect = "uk";
                inline_height = 20;
                show_preview = true;
                style = "compact";

                # History settings
                update_check = false;
              }
              // lib.optionalAttrs (cfg.sync.enable && cfg.sync.keyFile != null) {
                #key_path = cfg.sync.keyFile;
              }
              // lib.optionalAttrs (cfg.sync.enable && cfg.sync.sessionFile != null) {
                #session_path = cfg.sync.sessionFile;
              };
            };

            # Install atuin in home.packages to ensure it's available when nushell starts
            home.packages = [ pkgs.atuin ];
          }

          (mkIf nushellEnabled {
            # Load after fzf so atuin keeps Ctrl-R in nushell.
            programs.nushell.extraConfig = lib.mkOrder 2000 ''
              source ${atuinNushellInit}
            '';
          })
        ]
      );
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ atuinHomeModule ];
    }

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".local/share/atuin"
            ".config/atuin"
          ];
        }) enabledUsers;
      };
    })
  ];
}
