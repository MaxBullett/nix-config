{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkMerge;
  cfg = config.domains.development.docker;

  # Auto-detect if btrfs is in use
  usingBtrfs = config.domains.storage.btrfs.enable or false;
in
{
  options.domains.development.docker = {
    enable = mkEnableOption "Docker container runtime";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Enable Docker
      virtualisation.docker = {
        enable = true;

        # Auto-prune weekly with --all --volumes
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

      # Set oci-containers backend to docker
      virtualisation.oci-containers.backend = "docker";
    }

    # Conditional persistence
    (mkIf (config.domains.storage.btrfs.preservation.enable or false) {
      domains.storage.btrfs.preservation.mounts."/persist".directories = [
        "/var/lib/docker"
      ];
    })
  ]);
}
