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

      pythonEnv = cfg.package.withPackages (ps: with ps; cfg.packages);
    in
    {
      options.domains.development.python = {
        enable = mkEnableOption "Python development environment";

        package = mkOption {
          type = types.package;
          default = pkgs.python3;
          description = "Python package to use as base";
          example = lib.literalExpression "pkgs.python3";
        };

        packages = mkOption {
          type = types.listOf types.anything;
          default = [ ];
          description = "Python packages to install";
          example = lib.literalExpression ''
            [ numpy pandas jupyter ipython ]
          '';
        };
      };

      config = mkIf cfg.enable {
        home.packages = [ pythonEnv ];
      };
    };
in
{
  config = {
    home-manager.sharedModules = [ pythonHomeModule ];
  };
}
