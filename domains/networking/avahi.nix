{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.domains.networking.avahi;
  preservationEnabled = config.domains.storage.btrfs.preservation.enable or false;
in
{
  options.domains.networking.avahi = {
    enable = mkEnableOption "Avahi mDNS/DNS-SD service discovery";

    nssmdns = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable mDNS NSS (Name Service Switch) support.
        Allows resolving .local hostnames.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open firewall ports for mDNS (5353/udp).
        Required for service discovery to work.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = cfg.nssmdns;
      inherit (cfg) openFirewall;
    };

    # Conditional persistence: Avahi service state
    domains.storage.btrfs.preservation.mounts."/persist".directories = mkIf preservationEnabled [
      "/var/lib/avahi-daemon"
    ];
  };
}
