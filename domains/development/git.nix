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

  # Collect all users with git enabled
  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.development.git.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  # Home-manager module that provides per-user options
  gitHomeModule =
    { config, ... }:
    let
      cfg = config.domains.development.git;
    in
    {
      options.domains.development.git = {
        enable = mkEnableOption "Git version control";

        userName = mkOption {
          type = types.str;
          description = "User name for git commits";
          example = "John Doe";
        };

        userEmail = mkOption {
          type = types.str;
          description = "User email for git commits";
          example = "john@example.com";
        };

        signing = {
          enable = mkEnableOption "commit signing" // {
            default = true;
          };

          key = mkOption {
            type = types.str;
            description = ''
              Path to SSH public key for signing commits.

              For SSH signing, this should be the path to your public key.
              The corresponding private key must be available to ssh-agent.
            '';
            example = "~/.ssh/id_ed25519.pub";
          };
        };

        delta = {
          enable = mkEnableOption "Delta syntax highlighting" // {
            default = true;
          };

          theme = mkOption {
            type = types.str;
            default = "catppuccin_macchiato";
            description = "Delta color theme";
            example = "gruvbox-dark";
          };
        };

        defaultBranch = mkOption {
          type = types.str;
          default = "main";
          description = "Default branch name for new repositories";
        };

        aliases = mkOption {
          type = types.attrsOf types.str;
          default = {
            co = "checkout";
            br = "branch";
            st = "status -sb";
            ci = "commit";
            last = "log -1 HEAD";
            unstage = "reset HEAD --";
            graph = "log --graph --oneline --decorate --all";
          };
          description = ''
            Git aliases (git-internal, work in any shell).

            These are added to git config and invoked as: git <alias>
          '';
        };

        extraConfig = mkOption {
          type = types.attrs;
          default = { };
          description = "Additional git configuration options";
          example = {
            pull.rebase = true;
            fetch.prune = true;
          };
        };
      };

      config = mkIf cfg.enable {
        programs.git = {
          enable = true;
          package = pkgs.git;

          inherit (cfg) userName userEmail aliases;

          # Sensible defaults
          extraConfig = lib.mkMerge [
            {
              # Default branch
              init.defaultBranch = cfg.defaultBranch;

              # Better defaults
              pull.rebase = true;
              fetch.prune = true;
              push.autoSetupRemote = true;
              rebase.autoStash = true;

              # Colors
              color.ui = "auto";

              # Editor respects EDITOR env var
              core.editor = lib.mkDefault "$EDITOR";
            }

            # SSH signing configuration
            (mkIf cfg.signing.enable {
              commit.gpgsign = true;
              tag.gpgsign = true;
              gpg.format = "ssh";
              user.signingkey = cfg.signing.key;
            })

            # Delta configuration
            (mkIf cfg.delta.enable {
              core.pager = "delta";
              interactive.diffFilter = "delta --color-only";
              delta = {
                navigate = true;
                light = false;
                side-by-side = false;
                line-numbers = true;
                syntax-theme = cfg.delta.theme;
              };
              merge.conflictstyle = "diff3";
              diff.colorMoved = "default";
            })

            # User's extra config
            cfg.extraConfig
          ];
        };

        # Install delta if enabled
        home.packages = lib.optional cfg.delta.enable pkgs.delta;
      };
    };
in
{
  config = mkMerge [
    # Inject the git home-manager module into all users
    {
      home-manager.sharedModules = [ gitHomeModule ];
    }

    # System-level configuration when any user has git enabled
    (mkIf anyEnabled {
      # Ensure git is available system-wide
      environment.systemPackages = [ pkgs.git ];
    })

    # Conditional persistence for all enabled users
    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/preserve" = {
        users = mapAttrs (username: _: {
          files = [
            # Git config is generated, but preserve any local changes
            ".gitconfig"
          ];
        }) enabledUsers;
      };
    })
  ];
}
