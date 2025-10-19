{ pkgs, ... }:
{
  home = {
    username = "max";
    homeDirectory = "/home/max";
    packages = [
      pkgs.htop
      pkgs.jq
    ];
  };

  programs.git.enable = true;

  home.stateVersion = "25.05";
}
