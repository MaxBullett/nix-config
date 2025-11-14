{
  description = "DDD NixOS flake";
  inputs = {
    # Nix Packages (https://search.nixos.org/packages)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Hardware optimizations (https://github.com/NixOS/nixos-hardware)
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    # Home Manager (https://mipmip.github.io/home-manager-option-search)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management (https://github.com/Mic92/sops-nix)
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private secrets repo (https://github.com/MaxBullett/nix-secrets)
    nix-secrets = {
      url = "git+ssh://git@github.com/MaxBullett/nix-secrets.git?ref=main&shallow=1";
      flake = false;
    };

    # Declarative disk partitioning (https://github.com/nix-community/disko)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix theming framework (https://nix-community.github.io/stylix/)
    # Pinned to before opencode module was added (which has compatibility issues)
    stylix = {
      url = "github:nix-community/stylix/8d008296a1b3be9b57ad570f7acea00dd2fc92db";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Ephemeral-state management using preservation https://github.com/nix-community/preservation
    preservation.url = "github:nix-community/preservation";

    # Pre-commit hooks (https://github.com/cachix/git-hooks.nix)
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      # Custom lib extension
      inherit (nixpkgs) lib;
      l = import ./lib { inherit lib inputs self; };

      # Architectures
      systems = [
        "x86_64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      # Formatter (https://github.com/NixOS/nixfmt)
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      # Checks
      checks = forAllSystems (
        pkgs:
        let
          system = pkgs.system or pkgs.stdenv.hostPlatform.system;
        in
        import ./checks.nix { inherit inputs system pkgs; }
      );

      # Development shells
      devShells = forAllSystems (
        pkgs:
        let
          system = pkgs.system or pkgs.stdenv.hostPlatform.system;
          checks = import ./checks.nix { inherit inputs system pkgs; };
        in
        {
          default = pkgs.mkShell {
            inherit (checks.pre-commit-check) shellHook;
            buildInputs = checks.pre-commit-check.enabledPackages;
          };
        }
      );

      # Hosts
      nixosConfigurations = lib.genAttrs l.listHostNames (
        host:
        let
          system = l.systemForHost host;
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs l;
            hostName = host;
          };
          modules = l.mkHostModules host [
            ./compositions/hosts/${host}/default.nix
          ];
        }
      );

      lib = l;
    };
}
