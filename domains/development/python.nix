{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  pythonHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.development.python;
    in
    {
      options.domains.development.python = {
        enable = mkEnableOption "Python interpreter";

        package = mkOption {
          type = types.package;
          default = pkgs.python312;
          description = "Python package to install";
          example = lib.literalExpression "pkgs.python313";
        };
      };

      config = mkIf cfg.enable {
        home.packages = [ cfg.package ];
      };
    };
in
{
  config = {
    home-manager.sharedModules = [ pythonHomeModule ];
  };
}
