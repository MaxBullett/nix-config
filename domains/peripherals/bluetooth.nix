{
  config,
  lib,
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

  cfg = config.domains.peripherals.bluetooth;
in
{
  options.domains.peripherals.bluetooth = {
    enable = mkEnableOption "Bluetooth";

    powerOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = "Power on Bluetooth adapter on boot.";
    };

    autoSwitch = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically switch audio output to Bluetooth devices when they connect.";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional settings for BlueZ configuration.";
      example = {
        General.Experimental = true;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      hardware.bluetooth = {
        enable = true;
        inherit (cfg) powerOnBoot settings;
      };
    }

    (mkIf config.domains.storage.btrfs.preservation.enable {
      domains.storage.btrfs.preservation.mounts."/persist".directories = [
        "/var/lib/bluetooth"
      ];
    })

    # LC3 codec support for Bluetooth LE Audio (when WirePlumber is available)
    (mkIf
      (config.services.pipewire.wireplumber.enable or false && cfg.settings.General.Experimental or false)
      {
        environment.etc."wireplumber/wireplumber.conf.d/10-bluez-lc3.conf".text = ''
          monitor.bluez.properties = {
            bluez5.enable-lc3 = true
          }
        '';
      }
    )

    # Auto-switch audio output to Bluetooth devices when they connect
    (mkIf (cfg.autoSwitch && config.services.pipewire.wireplumber.enable or false) {
      environment.etc."wireplumber/wireplumber.conf.d/51-bluetooth-autoswitch.conf".text = ''
        monitor.bluez.rules = [
          {
            matches = [
              { node.name = "~bluez_output.*" }
            ]
            actions = {
              update-props = {
                priority.session = 2000
              }
            }
          }
        ]
      '';
    })
  ]);
}
