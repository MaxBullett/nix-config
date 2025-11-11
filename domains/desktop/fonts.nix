{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.domains.desktop.fonts;
in
{
  options.domains.desktop.fonts = {
    enable = mkEnableOption "system fonts with programming ligatures and icons";
  };

  config = mkIf cfg.enable {
    fonts = {
      fontconfig.enable = true;

      packages = with pkgs; [
        # Monospaced fonts with programming ligatures (Nerd Font patched)
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
        nerd-fonts.symbols-only

        # Emoji support
        noto-fonts-emoji
        noto-fonts-color-emoji

        # General purpose fonts
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif

        # Icon fonts
        font-awesome
        material-design-icons
      ];

      fontconfig.defaultFonts = {
        monospace = [
          "JetBrainsMono Nerd Font"
          "Noto Color Emoji"
        ];
        sansSerif = [
          "Noto Sans"
          "Noto Color Emoji"
        ];
        serif = [
          "Noto Serif"
          "Noto Color Emoji"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
