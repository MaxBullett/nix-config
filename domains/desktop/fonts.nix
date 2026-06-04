{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  cfg = config.domains.desktop.fonts;
in
{
  options.domains.desktop.fonts = {
    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Font packages to install system-wide.";
    };
  };

  config = {
    fonts.packages = cfg.packages;
  };
}
