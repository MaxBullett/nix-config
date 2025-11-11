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
    mkMerge
    mkOption
    types
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.desktop.xdg.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  xdgDirType = types.nullOr (
    types.submodule {
      options = {
        path = mkOption {
          type = types.str;
          description = "Directory path relative to home.";
          example = "docs";
        };

        mountPoint = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Persistence mount point for this directory.
            Common values: "/persist" (ephemeral), "/preserve" (snapshotted).
            Set to null to not persist this directory.
          '';
          example = "/preserve";
        };
      };
    }
  );

  xdgHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.desktop.xdg;
    in
    {
      options.domains.desktop.xdg = {
        enable = mkEnableOption "XDG user directories";

        createDirectories = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to automatically create the XDG directories.";
        };

        desktop = mkOption {
          type = xdgDirType;
          default = null;
          description = "Desktop directory configuration.";
          example = {
            path = "desktop";
            mountPoint = null;
          };
        };

        documents = mkOption {
          type = xdgDirType;
          default = null;
          description = "Documents directory configuration.";
          example = {
            path = "docs";
            mountPoint = "/preserve";
          };
        };

        download = mkOption {
          type = xdgDirType;
          default = null;
          description = "Downloads directory configuration.";
          example = {
            path = "downloads";
            mountPoint = "/persist";
          };
        };

        music = mkOption {
          type = xdgDirType;
          default = null;
          description = "Music directory configuration.";
          example = {
            path = "music";
            mountPoint = "/preserve";
          };
        };

        pictures = mkOption {
          type = xdgDirType;
          default = null;
          description = "Pictures directory configuration.";
          example = {
            path = "pictures";
            mountPoint = "/preserve";
          };
        };

        publicShare = mkOption {
          type = xdgDirType;
          default = null;
          description = "Public share directory configuration.";
          example = {
            path = "public";
            mountPoint = null;
          };
        };

        templates = mkOption {
          type = xdgDirType;
          default = null;
          description = "Templates directory configuration.";
          example = {
            path = "templates";
            mountPoint = null;
          };
        };

        videos = mkOption {
          type = xdgDirType;
          default = null;
          description = "Videos directory configuration.";
          example = {
            path = "videos";
            mountPoint = "/preserve";
          };
        };
      };

      config = mkIf cfg.enable {
        xdg.userDirs = {
          enable = true;
          inherit (cfg) createDirectories;

          # Convert relative paths to $HOME-prefixed paths
          desktop = if cfg.desktop != null then "$HOME/${cfg.desktop.path}" else null;
          documents = if cfg.documents != null then "$HOME/${cfg.documents.path}" else null;
          download = if cfg.download != null then "$HOME/${cfg.download.path}" else null;
          music = if cfg.music != null then "$HOME/${cfg.music.path}" else null;
          pictures = if cfg.pictures != null then "$HOME/${cfg.pictures.path}" else null;
          publicShare = if cfg.publicShare != null then "$HOME/${cfg.publicShare.path}" else null;
          templates = if cfg.templates != null then "$HOME/${cfg.templates.path}" else null;
          videos = if cfg.videos != null then "$HOME/${cfg.videos.path}" else null;
        };
      };
    };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ xdgHomeModule ];
    }

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts =
        let
          # Collect all mount points used across all enabled users
          allMountPoints = lib.unique (
            lib.flatten (
              map (
                userCfg:
                let
                  xdgCfg = userCfg.domains.desktop.xdg;
                  dirs = [
                    xdgCfg.desktop
                    xdgCfg.documents
                    xdgCfg.download
                    xdgCfg.music
                    xdgCfg.pictures
                    xdgCfg.publicShare
                    xdgCfg.templates
                    xdgCfg.videos
                  ];
                in
                lib.filter (m: m != null) (map (dir: if dir != null then dir.mountPoint else null) dirs)
              ) (lib.attrValues enabledUsers)
            )
          );
        in
        lib.genAttrs allMountPoints (mountPoint: {
          users = mapAttrs (username: userCfg: {
            directories =
              let
                xdgCfg = userCfg.domains.desktop.xdg;

                # All XDG directories
                allDirs = [
                  xdgCfg.desktop
                  xdgCfg.documents
                  xdgCfg.download
                  xdgCfg.music
                  xdgCfg.pictures
                  xdgCfg.publicShare
                  xdgCfg.templates
                  xdgCfg.videos
                ];

                # Filter for directories assigned to this mount point
                dirsForThisMount = lib.filter (dir: dir != null && dir.mountPoint == mountPoint) allDirs;

                # Extract the paths
                dirPaths = map (dir: dir.path) dirsForThisMount;
              in
              dirPaths;
          }) enabledUsers;
        });
    })
  ];
}
