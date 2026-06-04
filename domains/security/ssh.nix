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
    { config, lib, ... }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
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
            Use this only for directives not representable as settings blocks.
          '';
          example = ''
            ControlMaster auto
            ControlPath ~/.ssh/sockets/%r@%h:%p
            ControlPersist 10m
          '';
        };

        settings = mkOption {
          type = lib.hm.types.dagOf (
            types.submodule {
              freeformType = types.attrsOf types.anything;
            }
          );
          default = { };
          description = ''
            SSH host configuration blocks, passed directly to `programs.ssh.settings`.
            Attribute names are `Host` patterns unless they start with `Host ` or
            `Match `, in which case they are used as-is as the block header.
            Option names follow OpenSSH directive naming (PascalCase).
          '';
          example = lib.literalExpression ''
            {
              "github.com" = {
                IdentityFile = "~/.ssh/id_ed25519";
                IdentitiesOnly = true;
              };
              "*.example.com" = {
                User = "admin";
                Port = 2222;
              };
            }
          '';
        };
      };

      config = mkIf userCfg.enable {
        programs.ssh = {
          enable = true;
          inherit (userCfg) extraConfig;
          enableDefaultConfig = false;
          settings = userCfg.settings // {
            "*" = {
              AddKeysToAgent = "yes";
            }
            // (userCfg.settings."*" or { });
          };
        };

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
