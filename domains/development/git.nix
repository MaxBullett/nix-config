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
    _: userCfg: userCfg.domains.development.git.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

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

          inherit (cfg)
            userName
            userEmail
            aliases
            ;

          extraConfig = lib.mkMerge [
            {
              init.defaultBranch = cfg.defaultBranch;

              pull.rebase = true;
              fetch.prune = true;
              push.autoSetupRemote = true;
              rebase.autoStash = true;
              color.ui = "auto";
              core.editor = lib.mkDefault "$EDITOR";
            }

            (mkIf cfg.signing.enable {
              commit.gpgsign = true;
              tag.gpgsign = true;
              gpg.format = "ssh";
              user.signingkey = cfg.signing.key;
            })

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

            cfg.extraConfig
          ];
        };

        home.packages = lib.optional cfg.delta.enable pkgs.delta;
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ gitHomeModule ];
    }

    (mkIf anyEnabled {
      environment.systemPackages = [ pkgs.git ];
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/git"
          ];
        }) enabledUsers;
      };
    })
  ];
}
