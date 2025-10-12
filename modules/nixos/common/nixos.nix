{
  inputs,
  lib,
  outputs,
  ...
}:
{
  nixpkgs = {
    overlays = [
      outputs.overlays.default
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix.settings = {
    allow-import-from-derivation = true;
    auto-optimise-store = true;
    builders-use-substitutes = true;
    connect-timeout = 5;
    download-buffer-size = 524288000; # 500MB
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    fallback = true; # Don't hard fail if a binary cache isn't available, since some systems roam
    max-free = 1000000000; # 1GB
    min-free = 128000000; # 128MB
    require-sigs = true;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://maxbullett.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "maxbullett.cachix.org-1:/6uBIAw06/eUnFR/UTgTk4w9ZfSAtrf3a1R9aOkpixY="
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
    warn-dirty = false;
  };

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 20d --keep 20";
    };
    flake = lib.mkDefault inputs.self.outPath;
  };

  system.autoUpgrade = {
    enable = inputs.self ? rev; # Avoid auto-upgrades when working on repo locally
    dates = "hourly";
    flags = [ "--refresh" ];
    flake = "git://github.com/EmergentMind/nix-config?ref=main";
  };

  i18n = {
    defaultLocale = lib.mkDefault "en_IE.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "en_DK.UTF-8";
    };
  };

  time.timeZone = lib.mkDefault "Europe/Berlin";
  services.timesyncd = {
    enable = true;
    servers = [
      "time.cloudflare.com"
      "pool.ntp.org"
    ];
  };

  security.sudo.extraConfig = ''
    Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
    Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
    Defaults timestamp_timeout=120 # only ask for password every 2h
    Defaults env_keep+=SSH_AUTH_SOCK # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
  '';

  # Database for aiding terminal-based programs
  environment.enableAllTerminfo = true;
}
