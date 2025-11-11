{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkMerge;
  cfg = config.domains.development.docker;

  usingBtrfs = config.domains.storage.btrfs.enable or false;
in
{
  options.domains.development.docker = {
    enable = mkEnableOption "Docker container runtime";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      virtualisation.docker = {
        enable = true;

        autoPrune = {
          enable = true;
          dates = "weekly";
          flags = [
            "--all"
            "--volumes"
          ];
        };

        # Use btrfs storage driver if btrfs is enabled, otherwise overlay2
        storageDriver = if usingBtrfs then "btrfs" else "overlay2";
      };

      virtualisation.oci-containers.backend = "docker";
    }

    (mkIf (config.domains.storage.btrfs.preservation.enable or false) {
      domains.storage.btrfs.preservation.mounts."/persist".directories = [
        "/var/lib/docker"
      ];
    })
  ]);
}
