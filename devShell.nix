{
  checks,
  pkgs ?
    # If pkgs is not defined, instantiate nixpkgs from locked commit
    let
      lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
      nixpkgs = fetchTarball {
        url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
        sha256 = lock.narHash;
      };
    in
    import nixpkgs { overlays = [ ]; },
  ...
}:
{
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";

    inherit (checks.pre-commit-check) shellHook;
    buildInputs = checks.pre-commit-check.enabledPackages;
    BOOTSTRAP_USER = "max";
    BOOTSTRAP_SSH_PORT = "22";
    BOOTSTRAP_SSH_KEY = "~/.ssh/id_ed25519";

    nativeBuildInputs = builtins.attrValues {
      inherit (pkgs)

        age
        cachix
        deadnix
        flake-checker
        git
        home-manager
        just
        jq
        nh
        nix
        nixfmt-rfc-style
        pre-commit
        sops
        ssh-to-age
        statix
        yq-go
        ;
    };
  };
}
