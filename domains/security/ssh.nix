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

  cfg = config.domains.security.ssh;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.security.ssh.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  sshHomeModule =
    { config, ... }:
    let
      userCfg = config.domains.security.ssh;
    in
    {
      options.domains.security.ssh = {
        enable = mkEnableOption "SSH client configuration";

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Raw SSH config to add to ~/.ssh/config.
            For host-specific settings, prefer using matchBlocks for type safety.
            Use this only for options not available in matchBlocks.
          '';
          example = ''
            # Advanced options not available in matchBlocks
            ControlMaster auto
            ControlPath ~/.ssh/sockets/%r@%h:%p
            ControlPersist 10m
          '';
        };

        matchBlocks = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                hostname = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "The hostname to connect to";
                };

                user = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "User to log in as";
                };

                port = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Port to connect to on the remote host";
                };

                identityFile = mkOption {
                  type = types.nullOr (types.either types.str (types.listOf types.str));
                  default = null;
                  description = "Identity file(s) to use for authentication";
                };

                identitiesOnly = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Only use identity files configured in SSH config";
                };

                forwardAgent = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Forward SSH agent to the remote machine";
                };

                extraOptions = mkOption {
                  type = types.attrsOf types.str;
                  default = { };
                  description = "Additional SSH options for this host";
                };
              };
            }
          );
          default = { };
          description = ''
            SSH host configurations using structured options.
            Alternative to extraConfig for type-safe host configuration.
          '';
          example = lib.literalExpression ''
            {
              "github.com" = {
                identityFile = "~/.ssh/id_ed25519";
                identitiesOnly = true;
              };
              "*.example.com" = {
                user = "admin";
                port = 2222;
              };
            }
          '';
        };

      };

      config = mkIf userCfg.enable {
        programs.ssh = {
          enable = true;
          inherit (userCfg) extraConfig;

          # Disable default config to avoid future deprecation warnings
          enableDefaultConfig = false;

          # Manually configure defaults via global match block
          matchBlocks = userCfg.matchBlocks // {
            "*" = {
              # Automatically add keys to agent when first used
              addKeysToAgent = "yes";
            };
          };
        };

        # Ensure .ssh directory exists with correct permissions
        home.file.".ssh/.keep".text = "";
        home.file.".ssh/.keep".onChange = ''
          chmod 700 ~/.ssh
        '';
      };
    };
in
{
  options.domains.security.ssh = {
    server = {
      enable = mkEnableOption "SSH server (sshd)";

      port = mkOption {
        type = types.int;
        default = 22;
        description = "Port for SSH server to listen on";
      };

      permitRootLogin = mkOption {
        type = types.str;
        default = "prohibit-password";
        description = "Whether root can log in via SSH";
      };

      passwordAuthentication = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to allow password authentication";
      };
    };
  };

  config = mkMerge [
    {
      home-manager.sharedModules = [ sshHomeModule ];
    }

    (mkIf anyEnabled {
      # System-wide SSH client configuration
      programs.ssh = {
        startAgent = false; # SSH agent provided by desktop environment

        # System-wide SSH client defaults
        extraConfig = ''
          # Use modern key exchange algorithms
          KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

          # Use modern ciphers
          Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

          # Use modern MACs
          MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

          # Prefer modern host key algorithms
          HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256

          # Security hardening
          HashKnownHosts yes
          StrictHostKeyChecking ask
          VerifyHostKeyDNS ask
        '';
      };

      # Ensure SSH package is available system-wide
      environment.systemPackages = [ pkgs.openssh ];
    })

    # Persist user .ssh directories and system /etc/ssh
    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        # User SSH directories
        users = mapAttrs (username: _: {
          directories = [
            ".ssh"
          ];
        }) enabledUsers;

        # System SSH directory (for host keys used by SOPS and optionally sshd)
        directories = [
          {
            directory = "/etc/ssh";
            inInitrd = true; # SSH host keys needed for SOPS decryption in initrd
          }
        ];
      };
    })

    # SSH Server configuration
    (mkIf cfg.server.enable {
      services.openssh = {
        enable = true;
        ports = [ cfg.server.port ];
        settings = {
          PermitRootLogin = cfg.server.permitRootLogin;
          PasswordAuthentication = cfg.server.passwordAuthentication;
        };
      };
    })
  ];
}
