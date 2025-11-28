{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    filterAttrs
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.shell.nushell.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  nushellHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.shell.nushell;

      defaultPlugins = with pkgs.nushellPlugins; [
        polars
        gstat
        formats
        query
      ];
    in
    {
      options.domains.shell.nushell = {
        enable = mkEnableOption "nushell shell";

        shellAliases = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Shell aliases for nushell.";
          example = {
            ll = "ls -l";
            la = "ls -la";
          };
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "Extra configuration to add to config.nu.";
        };
      };

      config = mkIf cfg.enable {
        programs.nushell = {
          enable = true;

          # Shell configuration (config.nu)
          extraConfig = ''
            # Basic configuration
            $env.config = {
              show_banner: false
              rm: {always_trash: true}
              use_kitty_protocol: true

              table: {
                mode: rounded
                index_mode: auto
                show_empty: true
              }

              cursor_shape: {
                vi_insert: line
                vi_normal: block
              }

              history: {
                max_size: 100000
                sync_on_enter: true
                file_format: "sqlite"
              }
            }

            # Common ls aliases and sort them by type and then name
            # Inspired by https://github.com/nushell/nushell/issues/7190
            def lla [...args] { ls -la ...(if $args == [] {["."]} else {$args}) | sort-by type name -i }
            def la  [...args] { ls -a  ...(if $args == [] {["."]} else {$args}) | sort-by type name -i }
            def ll  [...args] { ls -l  ...(if $args == [] {["."]} else {$args}) | sort-by type name -i }
            def l   [...args] { ls     ...(if $args == [] {["."]} else {$args}) | sort-by type name -i }

            # Register plugins
            plugin add ${pkgs.nushellPlugins.polars}/bin/nu_plugin_polars
            plugin add ${pkgs.nushellPlugins.gstat}/bin/nu_plugin_gstat
            plugin add ${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats
            plugin add ${pkgs.nushellPlugins.query}/bin/nu_plugin_query

            # Shell aliases
            ${concatStringsSep "\n" (mapAttrsToList (name: value: "alias ${name} = ${value}") cfg.shellAliases)}

            # User's extra configuration
            ${cfg.extraConfig}
          '';

          inherit (cfg) shellAliases;
        };

        home.packages = defaultPlugins;

        # Configure bash to start nushell for interactive sessions
        # Nushell is not POSIX-compliant and should not be used as a login shell
        # See: https://wiki.nixos.org/wiki/Nushell
        programs.bash = {
          enable = true;
          initExtra = ''
            if ! [ "$TERM" = "dumb" ] && [ -z "$BASH_EXECUTION_STRING" ]; then
              exec nu
            fi
          '';
        };
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ nushellHomeModule ];
    }

    (mkIf anyEnabled {
      environment.shells = [ pkgs.nushell ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/nushell"
            ".local/share/nushell"
          ];
        }) enabledUsers;
      };
    })
  ];
}
