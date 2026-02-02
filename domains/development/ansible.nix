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
    mkOption
    types
    ;

  cfg = config.domains.development.ansible;
in
{
  options.domains.development.ansible = {
    enable = mkEnableOption "Ansible automation tool";

    package = mkOption {
      type = types.package;
      default = pkgs.ansible;
      description = "The Ansible package to use.";
    };

    lint.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Include ansible-lint for playbook linting.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = "[ pkgs.sshpass ]";
      description = "Additional packages to include (e.g., sshpass for password auth).";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ]
    ++ lib.optional cfg.lint.enable pkgs.ansible-lint
    ++ cfg.extraPackages;
  };
}
