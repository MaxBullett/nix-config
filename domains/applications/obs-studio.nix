{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    flatten
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  enabledUsers = filterAttrs (
    _: userCfg: userCfg.domains.applications.obs-studio.enable or false
  ) config.home-manager.users;

  anyEnabled = enabledUsers != { };

  defaultPlugins = with pkgs.obs-studio-plugins; [
    wlrobs # Wayland capture support
    obs-backgroundremoval # AI background removal
    obs-pipewire-audio-capture # PipeWire audio capture
    obs-vaapi # Hardware-accelerated encoding (AMD/Intel)
    obs-gstreamer # GStreamer integration
    obs-vkcapture # Vulkan/OpenGL game capture
  ];

  allPlugins =
    let
      userPluginLists = lib.mapAttrsToList (
        _: userCfg:
        let
          plugins = userCfg.domains.applications.obs-studio.plugins or [ ];
        in
        if plugins == [ ] then defaultPlugins else plugins
      ) enabledUsers;
      allPluginsList = lib.unique (flatten userPluginLists);
    in
    allPluginsList;

  anyVirtualCamera = builtins.any (
    userCfg: userCfg.domains.applications.obs-studio.enableVirtualCamera or false
  ) (builtins.attrValues enabledUsers);

  obsHomeModule = {
    options.domains.applications.obs-studio = {
      enable = mkEnableOption "OBS Studio screen recording and streaming";

      enableVirtualCamera = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable OBS Studio virtual camera support.
          Allows using OBS as a virtual webcam in other applications.
        '';
      };

      plugins = mkOption {
        type = with types; listOf package;
        default = [ ];
        description = ''
          List of OBS Studio plugins to install.
          Plugins extend OBS functionality (e.g., sources, filters, encoders).
          Leave empty to use default plugins.
        '';
        example = lib.literalExpression ''
          with pkgs.obs-studio-plugins; [
            wlrobs
            obs-pipewire-audio-capture
          ]
        '';
      };
    };
  };
in
{
  config = mkMerge [
    {
      home-manager.sharedModules = [ obsHomeModule ];
    }

    (mkIf anyEnabled {
      programs.obs-studio = {
        enable = true;
        enableVirtualCamera = anyVirtualCamera;
        plugins = allPlugins;
      };

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    (mkIf (anyEnabled && (config.domains.storage.btrfs.preservation.enable or false)) {
      domains.storage.btrfs.preservation.mounts."/persist" = {
        users = mapAttrs (username: _: {
          directories = [
            ".config/obs-studio"
          ];
        }) enabledUsers;
      };
    })
  ];
}
