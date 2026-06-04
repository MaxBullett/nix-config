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

      texliveEnv = pkgs.texlive.combine {
        inherit (pkgs.texlive)
          scheme-basic
          # XeLaTeX font loading
          fontspec
          unicode-math
          # Extra packages
          fontawesome6
          accsupp
          tcolorbox
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
          xstring
          etoolbox
          iftex
          hyperref
          bookmark
          tools
          ;
      };
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
