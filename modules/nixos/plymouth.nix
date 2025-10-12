{
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = [ pkgs.adi1090x-plymouth-themes ];
  boot = {
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
    ];
    loader.timeout = 0;
    plymouth = {
      enable = true;
      theme = lib.mkForce "hexagon_hud";
      themePackages = [
        (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "hexagon_hud" ]; })
      ];
    };
  };
}
