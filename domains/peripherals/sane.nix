{
  config,
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

  cfg = config.domains.peripherals.sane;
in
{
  options.domains.peripherals.sane = {
    enable = mkEnableOption "SANE scanning support";

    extraBackends = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional SANE backends for vendor-specific scanner support (e.g. hplip, brscan4).";
    };

    netScan.enable = mkEnableOption "network scanner sharing via saned";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      hardware.sane = {
        enable = true;
        inherit (cfg) extraBackends;
      };
      environment.systemPackages = with pkgs; [ simple-scan ];
    }

    (mkIf cfg.netScan.enable {
      services.saned.enable = true;
    })
  ]);
}
