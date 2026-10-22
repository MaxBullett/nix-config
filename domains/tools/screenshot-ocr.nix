# domains/tools/screenshot-ocr.nix
#
# Select a region of the screen, OCR it with tesseract and copy the recognised
# text to the clipboard. Built on slurp + grim, so it works on any compositor
# offering wlr-layer-shell and ext-image-copy-capture (COSMIC does). Bind the
# `screenshot-ocr` command to a key in the desktop's own shortcut settings.
{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    elem
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  screenshotOcrHomeModule =
    { config, ... }:
    let
      cfg = config.domains.tools.screenshot-ocr;

      # The stock package bundles every language (~1 GiB); only ship the ones asked for
      tesseract = pkgs.tesseract.override { inherit (cfg) enableLanguages; };

      screenshot-ocr = pkgs.writeShellApplication {
        name = "screenshot-ocr";

        runtimeInputs = with pkgs; [
          grim
          imagemagick_light # magick
          libnotify # notify-send
          perl
          slurp
          tesseract
          wl-clipboard
        ];

        text = ''
          notify() { notify-send --app-name="Screenshot OCR" "$@"; }

          # slurp reads predefined boxes from stdin when it isn't a TTY, and the
          # compositor spawns shortcuts with a stdin pipe that never closes; detach it.
          # slurp exits non-zero when the selection is cancelled (Esc / right click)
          geometry=$(slurp </dev/null) || exit 0

          # PPM rather than PNG: imagemagick_light is built without libpng
          capture=$(mktemp --suffix=.ppm)
          trap 'rm -f "$capture"' EXIT
          grim -t ppm -g "$geometry" "$capture"

          # Screen text is far below the resolution tesseract is trained on; at 1x it
          # drops umlauts and misreads punctuation. Upscale smoothly (grim -s would
          # scale nearest-neighbour, which hurts recognition).
          magick "$capture" -resize 200% "$capture"

          ocr() {
            tesseract "$capture" - -l ${concatStringsSep "+" cfg.enableLanguages} --psm "$1" \
              -c page_separator= 2>/dev/null || true
          }

          # tesseract mirrors the on-screen layout; turn it into text worth pasting:
          # one line per paragraph, paragraphs separated by a blank line.
          tidy() {
            perl -CSD -0777 -pe '
              s/\x{FB00}/ff/g; s/\x{FB01}/fi/g; s/\x{FB02}/fl/g; s/\x{FB03}/ffi/g; s/\x{FB04}/ffl/g;
              tr/\x{2018}\x{2019}\x{201A}\x{201B}\x{201C}\x{201D}\x{201E}\x{201F}/\x27\x27\x27\x27""""/;
              s/[^\S\n]+/ /g;
              s/^ +| +$//mg;
              # Lines with no letter or digit are borders, icons or the cursor
              s/^[^\p{L}\p{N}\n]+(?:\n|\z)//mg;
              # A word hyphenated across a line break, or a compound like Linux-Kernel
              s/(\p{L})[-\x{2010}\x{AD}]\n(?=\p{Ll})/$1/g;
              s/(\p{L}[-\x{2010}])\n(?=\p{Lu})/$1/g;
              s/(?<!\n)\n(?!\n)/ /g;
              s/\n{3,}/\n\n/g;
              s/^\s+|\s+$//g;
            '
          }

          # Automatic page segmentation copes with mixed layouts but can come back
          # empty on a snug crop of a single word; retry as one uniform text block.
          text=$(ocr 3 | tidy)
          if [[ -z "$text" ]]; then
            text=$(ocr 6 | tidy)
          fi

          if [[ -z "$text" ]]; then
            notify --icon=dialog-warning "No text recognised"
            exit 1
          fi

          printf '%s' "$text" | wl-copy

          # cosmic-notifications renders body markup, so escape the preview
          preview=$(printf '%s' "''${text:0:300}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
          notify --icon=edit-copy "Text copied to clipboard" "$preview"
        '';
      };
    in
    {
      options.domains.tools.screenshot-ocr = {
        enable = mkEnableOption "screenshot OCR - copy the text of a selected screen region";

        enableLanguages = mkOption {
          type = types.listOf types.str;
          default = [ "eng" ];
          example = [
            "deu"
            "eng"
          ];
          description = ''
            Tesseract languages to install and recognise, in priority order.
            Must include "eng", which tesseract needs to start.
          '';
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = elem "eng" cfg.enableLanguages;
            message = "domains.tools.screenshot-ocr.enableLanguages must include \"eng\".";
          }
        ];

        home.packages = [ screenshot-ocr ];
      };
    };
in
{
  home-manager.sharedModules = [ screenshotOcrHomeModule ];
}
