{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    types
    ;

  cfg = config.domains.desktop.cursors;
in
{
  options.domains.desktop.cursors = {
    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Cursor theme package to use.
        Set to null to use system default.

        For Catppuccin cursors, use:
        pkgs.catppuccin-cursors.<flavor><Accent>

        Available flavors: latte, frappe, macchiato, mocha
        Available accents: Blue, Flamingo, Green, Lavender, Maroon, Mauve,
                          Peach, Pink, Red, Rosewater, Sapphire, Sky,
                          Teal, Yellow, Dark, Light

        Examples:
        - pkgs.catppuccin-cursors.macchiatoSky
        - pkgs.catppuccin-cursors.mochaMauve
        - pkgs.catppuccin-cursors.latteLavender
      '';
      example = lib.literalExpression "pkgs.catppuccin-cursors.macchiatoSky";
    };

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Cursor theme name.
        Automatically derived from package if not specified.

        For Catppuccin cursors, this is usually "catppuccin-<flavor>-<accent>-cursors".
      '';
      example = "catppuccin-macchiato-sky-cursors";
    };

    size = mkOption {
      type = types.int;
      default = 24;
      description = "Cursor size in pixels.";
    };
  };

  config = mkIf (cfg.package != null) {
    # System-wide cursor configuration
    environment.systemPackages = [ cfg.package ];

    # Environment variables for cursor theme
    environment.variables = {
      XCURSOR_THEME = cfg.name;
      XCURSOR_SIZE = toString cfg.size;
    };

    # Home Manager integration for per-user settings
    home-manager.sharedModules = [
      {
        home.pointerCursor = {
          enable = true;
          inherit (cfg) package name size;
          gtk.enable = true;
          x11.enable = true;
        };
      }
    ];
  };
}
