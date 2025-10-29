{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.domains.boot.systemd-boot;
in
{
  options.domains.boot.systemd-boot = {
    enable = mkEnableOption "systemd-boot as the system EFI boot loader.";

    configurationLimit = mkOption {
      type = types.nullOr types.int;
      default = 5;
      description = "Number of boot entries to keep in the EFI System Partition (set null to accept upstream default).";
    };

    editor = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the systemd-boot editor is enabled at boot time.";
    };

    timeout = mkOption {
      type = types.int;
      default = 5;
      description = "Number of seconds the bootloader will show the menu for before booting default option.";
    };

    canTouchEfiVariables = mkOption {
      type = types.bool;
      default = true;
      description = "Whether systemd-boot may write EFI variables (requires firmware support).";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      loader = {
        systemd-boot = {
          enable = mkDefault true;
          inherit (cfg) configurationLimit editor;
        };
        inherit (cfg) timeout;
        efi = { inherit (cfg) canTouchEfiVariables; };
      };
      initrd.systemd.enable = mkDefault true;
    };
  };
}
