{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    (lib.custom.scanPaths ./.)
  ];

  # Minimal tools we need in all environments
  programs.zsh.enable = true;
  programs.git.enable = true;
  environment = {
    systemPackages = [
      pkgs.just
    ];
  };
}
