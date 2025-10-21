{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.domains.nix.nixpkgs;
in
{
  options.domains.nix.nixpkgs = {
    allowUnfree = mkOption {
      type = types.bool;
      default = false;
      description = "Allow installation of unfree (proprietary) packages.";
    };

    allowInsecure = mkOption {
      type = types.bool;
      default = false;
      description = "Allow installation of packages marked as insecure.";
    };

    permittedInsecurePackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of specific insecure packages to allow.";
      example = [
        "electron-25.9.0"
        "openssl-1.1.1w"
      ];
    };
  };

  config = {
    nixpkgs.config = {
      inherit (cfg)
        allowUnfree
        allowInsecure
        permittedInsecurePackages
        ;
    };
  };
}
