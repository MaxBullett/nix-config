{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;

  xelatexHomeModule =
    {
      config,
      ...
    }:
    let
      cfg = config.domains.tools.xelatex;

      texliveEnv = pkgs.texliveSmall.withPackages (
        ps: with ps; [
          # XeLaTeX engine
          xetex
          # XeLaTeX font loading
          fontspec
          unicode-math
          # Extra packages
          fontawesome6
          accsupp
          tcolorbox
          tikzfill
          pgf
          # Layout and spacing
          geometry
          fancyhdr
          parskip
          setspace
          ragged2e
          enumitem
          # Colour
          xcolor
          # Utilities
          xifthen
          ifmtarg
          xstring
          etoolbox
          iftex
          hyperref
          bookmark
          tools
        ]
      );
    in
    {
      options.domains.tools.xelatex = {
        enable = mkEnableOption "XeLaTeX typesetting environment";
      };

      config = mkIf cfg.enable {
        home.packages = [ texliveEnv ];
      };
    };
in
{
  config = {
    home-manager.sharedModules = [ xelatexHomeModule ];
  };
}
