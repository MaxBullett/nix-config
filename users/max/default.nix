{
  pkgs,
  ...
}:
{
  config = {
    users.users.max = {
      # user-specific bits that complement the base definition
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      packages = with pkgs; [
        git
        zsh
      ];
    };

    # example: home-manager, services, etc.
    # home-manager.users.${name} = { ... };
  };
}
