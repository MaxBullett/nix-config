{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.domains.desktop.stylix;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.domains.desktop.stylix = {
    enable = mkEnableOption "Stylix system-wide theming and fonts";

    scheme = mkOption {
      type = types.str;
      default = "catppuccin-macchiato";
      description = ''
        Base16 color scheme to use.
        Available schemes are in `pkgs.base16-schemes/share/themes/`.

        Popular options:
        - catppuccin-mocha (dark)
        - catppuccin-macchiato (dark)
        - catppuccin-frappe (dark)
        - catppuccin-latte (light)
        - gruvbox-dark-medium
        - nord
        - tokyo-night-dark
      '';
      example = "catppuccin-mocha";
    };

    polarity = mkOption {
      type = types.enum [
        "dark"
        "light"
      ];
      default = "dark";
      description = "Whether to use dark or light theme variant.";
    };

    wallpaper = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to wallpaper image.
        Stylix will use this for backgrounds and extract colors if needed.
      '';
      example = lib.literalExpression "./wallpaper.jpg";
    };

    fonts = {
      monospace = {
        name = mkOption {
          type = types.str;
          default = "JetBrainsMono Nerd Font";
          description = "Monospace font name for terminals and code editors.";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.nerd-fonts.jetbrains-mono;
          description = "Monospace font package.";
        };
      };

      sansSerif = {
        name = mkOption {
          type = types.str;
          default = "Noto Sans";
          description = "Sans-serif font name for UI elements.";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.noto-fonts;
          description = "Sans-serif font package.";
        };
      };

      serif = {
        name = mkOption {
          type = types.str;
          default = "Noto Serif";
          description = "Serif font name for documents.";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.noto-fonts;
          description = "Serif font package.";
        };
      };

      emoji = {
        name = mkOption {
          type = types.str;
          default = "Noto Color Emoji";
          description = "Emoji font name.";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.noto-fonts-color-emoji;
          description = "Emoji font package.";
        };
      };

      sizes = {
        applications = mkOption {
          type = types.int;
          default = 11;
          description = "Font size for applications (in points).";
        };

        terminal = mkOption {
          type = types.int;
          default = 12;
          description = "Font size for terminal applications (in points).";
        };

        desktop = mkOption {
          type = types.int;
          default = 10;
          description = "Font size for desktop UI elements (in points).";
        };

        popups = mkOption {
          type = types.int;
          default = 10;
          description = "Font size for popups and notifications (in points).";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    fonts = {
      fontconfig.enable = true;

      packages = with pkgs; [
        # Configured fonts
        cfg.fonts.monospace.package
        cfg.fonts.sansSerif.package
        cfg.fonts.serif.package
        cfg.fonts.emoji.package

        # Additional monospaced fonts with programming ligatures
        nerd-fonts.fira-code
        nerd-fonts.symbols-only

        # Additional general purpose fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif

        # Icon fonts
        font-awesome
        material-design-icons
      ];
    };

    stylix = mkMerge [
      {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.scheme}.yaml";
        inherit (cfg) polarity;

        fonts = {
          monospace = {
            inherit (cfg.fonts.monospace) package name;
          };
          sansSerif = {
            inherit (cfg.fonts.sansSerif) package name;
          };
          serif = {
            inherit (cfg.fonts.serif) package name;
          };
          emoji = {
            inherit (cfg.fonts.emoji) package name;
          };
          sizes = {
            inherit (cfg.fonts.sizes)
              applications
              terminal
              desktop
              popups
              ;
          };
        };
      }
      (mkIf (cfg.wallpaper != null) { image = cfg.wallpaper; })
    ];
  };
}
