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
  cfg = config.domains.development.ollama;
in
{
  options.domains.development.ollama = {
    enable = mkEnableOption "Ollama local LLM inference server";
    package = mkOption {
      type = types.package;
      default = pkgs.ollama;
      description = "Ollama package; select acceleration via pkgs.ollama[-rocm,-cuda,-vulkan,-cpu]";
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
    };
    loadModels = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables for the ollama service (e.g. host-specific GPU overrides)";
    };
  };

  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      inherit (cfg)
        package
        host
        loadModels
        environmentVariables
        ;
    };

    hardware.graphics.enable = true;
  };
}
