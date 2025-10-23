{
  config,
  hostName,
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    flatten
    listToAttrs
    map
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalString
    types
    ;
  cfg = config.domains.networking.networkmanager;
in
{
  options.domains.networking.networkmanager = {
    enable = mkEnableOption "NetworkManager";

    wifi = {
      backend = mkOption {
        type = types.enum [
          "wpa_supplicant"
          "iwd"
        ];
        default = "wpa_supplicant";
        description = "Wi-Fi backend used by NetworkManager.";
      };

      powersave = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Wi-Fi powersave via NetworkManager.";
      };
    };

    networks = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of network names to configure from SOPS secrets.

        Each network should have entries in your secrets file:
        ```yaml
        networks:
          network-name:
            ssid: "ActualSSID"
            psk: "wifi-password"
            hidden: true  # optional, for hidden SSIDs
        ```

        Then use: `networks = [ "network-name" ];`

        Note: These are managed declaratively. Manual changes via NetworkManager
        GUI will be overwritten on next rebuild. To modify a network, update
        the secret in nix-secrets and rebuild.
      '';
      example = [
        "home-wifi"
        "work-wifi"
      ];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Base NetworkManager configuration
    {
      networking.networkmanager = {
        enable = true;
        inherit (cfg) wifi;
      };
    }

    # iwd backend configuration
    (mkIf (cfg.wifi.backend == "iwd") {
      networking.wireless.iwd = {
        enable = true;
        settings = {
          Settings = {
            AutoConnect = true;
          };
        };
      };
    })

    # Conditional persistence
    (mkIf config.domains.storage.btrfs.preservation.enable {
      domains.storage.btrfs.preservation.mounts."/persist".directories = [
        "/etc/NetworkManager/system-connections"
        "/var/lib/NetworkManager"
      ]
      ++ lib.optionals (cfg.wifi.backend == "iwd") [ "/var/lib/iwd" ];
    })

    # Secret network configuration via SOPS templates
    (mkIf (cfg.networks != [ ]) {
      # Declare SOPS secrets for each network field (ssid, psk, hidden)
      sops.secrets = listToAttrs (
        flatten (
          map (name: [
            {
              name = "networks/${name}/ssid";
              value.sopsFile = mkDefault "${inputs.nix-secrets}/hosts/${hostName}/secrets.yaml";
            }
            {
              name = "networks/${name}/psk";
              value.sopsFile = mkDefault "${inputs.nix-secrets}/hosts/${hostName}/secrets.yaml";
            }
            {
              name = "networks/${name}/hidden";
              value = {
                sopsFile = mkDefault "${inputs.nix-secrets}/hosts/${hostName}/secrets.yaml";
                # Hidden is optional, so don't fail if missing
                restartUnits = [ ];
              };
            }
          ]) cfg.networks
        )
      );

      # Generate NetworkManager connection files using templates
      # Note: These are regenerated on every activation (declarative)
      sops.templates = listToAttrs (
        map (name: {
          inherit name;
          value = {
            content = ''
              [connection]
              id=${name}
              type=wifi
              autoconnect=true

              [wifi]
              ssid=''${config.sops.placeholder."networks/${name}/ssid"}
              mode=infrastructure
              ${optionalString (
                config.sops.secrets."networks/${name}/hidden" or null != null
              ) ''hidden=''${config.sops.placeholder."networks/${name}/hidden"}''}

              [wifi-security]
              key-mgmt=wpa-psk
              psk=''${config.sops.placeholder."networks/${name}/psk"}

              [ipv4]
              method=auto

              [ipv6]
              addr-gen-mode=stable-privacy
              method=auto
            '';
            path = "/etc/NetworkManager/system-connections/${name}.nmconnection";
            mode = "0600";
          };
        }) cfg.networks
      );
    })
  ]);
}
