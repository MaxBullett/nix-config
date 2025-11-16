{
  inputs,
  system,
  ...
}:
{
  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    default_stages = [ "pre-commit" ];
    hooks = {
      # General
      check-added-large-files = {
        enable = true;
        args = [ "--maxkb=2048" ]; # 2MB limit
      };
      check-case-conflicts.enable = true;
      check-executables-have-shebangs.enable = true;
      check-merge-conflicts.enable = true;
      check-shebang-scripts-are-executable.enable = false; # .envrc false positive
      check-symlinks.enable = true;
      detect-private-keys.enable = true;
      end-of-file-fixer.enable = true;
      fix-byte-order-marker.enable = true;
      forbid-submodules = {
        enable = true;
        name = "forbid submodules";
        description = "forbids any submodules in the repository";
        language = "fail";
        entry = "submodules are not allowed in this repository:";
        types = [ "directory" ];
      };
      trim-trailing-whitespace.enable = true;

      # Nix
      deadnix = {
        enable = true;
        settings = {
          edit = true;
          noLambdaArg = true;
        };
      };
      flake-checker.enable = true;
      nixfmt-rfc-style.enable = true;
      statix.enable = true;

      # Shell scripts
      shellcheck.enable = true;
      shfmt.enable = true;
    };
  };
}
