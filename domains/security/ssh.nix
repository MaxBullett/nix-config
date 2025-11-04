{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.domains.security.ssh;

  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;

  # Find all normal (non-system) users for SSH persistence
  normalUsers = filterAttrs (_: user: user.isNormalUser or false) config.users.users;
in
{
  options.domains.security.ssh = {
    enable = mkEnableOption "SSH client configuration";

    forwardAgent = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Forward SSH agent to remote hosts.

        When false (default), more secure - agent stays local.
        Enable per-host in matchBlocks for specific trusted servers.
      '';
    };

    hashKnownHosts = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Hash host names and addresses in known_hosts file.

        Improves privacy by obscuring which hosts you connect to.
      '';
    };

    keepAlive = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Send periodic keepalive messages to maintain connections.

          Prevents SSH sessions from timing out during idle periods.
          Essential for long-running sessions.
        '';
      };

      interval = mkOption {
        type = types.int;
        default = 60;
        description = ''
          Interval in seconds between keepalive messages.

          Default: 60 seconds
        '';
      };

      countMax = mkOption {
        type = types.int;
        default = 3;
        description = ''
          Number of keepalive messages sent without response before disconnecting.

          Default: 3 (disconnect after ~3 minutes of no response)
        '';
      };
    };

    multiplexing = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable connection multiplexing for better performance.

          Reuses existing SSH connections for subsequent sessions to the same host.
          Significantly speeds up repeated connections (e.g., git operations, multiple terminals).
        '';
      };

      controlPath = mkOption {
        type = types.str;
        default = "/tmp/ssh-%r@%h:%p";
        description = ''
          Path for control socket files.

          Variables: %r (remote user), %h (host), %p (port)
        '';
      };

      controlPersist = mkOption {
        type = types.str;
        default = "10m";
        description = ''
          How long to keep master connection alive after last session closes.

          Examples: "10m" (10 minutes), "1h" (1 hour), "yes" (forever)
        '';
      };
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Additional SSH client configuration.

        Will be appended to ~/.ssh/config (or system-wide config).
      '';
      example = ''
        Host *.internal
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      # System-wide SSH client configuration via extraConfig
      extraConfig = ''
        ${lib.optionalString (!cfg.forwardAgent) ''
          # Disable agent forwarding by default (security)
          ForwardAgent no
        ''}

        ${lib.optionalString cfg.forwardAgent ''
          # Enable agent forwarding
          ForwardAgent yes
        ''}

        ${lib.optionalString cfg.hashKnownHosts ''
          # Hash known hosts for privacy
          HashKnownHosts yes
        ''}

        ${lib.optionalString cfg.keepAlive.enable ''
          # Connection keep-alive
          ServerAliveInterval ${toString cfg.keepAlive.interval}
          ServerAliveCountMax ${toString cfg.keepAlive.countMax}
        ''}

        ${lib.optionalString cfg.multiplexing.enable ''
          # Connection multiplexing
          ControlMaster auto
          ControlPath ${cfg.multiplexing.controlPath}
          ControlPersist ${cfg.multiplexing.controlPersist}
        ''}

        ${cfg.extraConfig}
      '';
    };

    # Conditional persistence: SSH keys and known_hosts for all normal users
    domains.storage.btrfs.preservation.mounts = mkIf preservationEnabled {
      "/persist".users = mapAttrs (username: _: {
        directories = [ ".ssh" ];
      }) normalUsers;
    };
  };
}
