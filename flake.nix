{
  description = "Max's Nix configuration flake";
  inputs = {
    ### Official sources
    # Nix Packages (https://search.nixos.org/packages)
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Hardware optimizations (https://github.com/NixOS/nixos-hardware)
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    # Home Manager (https://mipmip.github.io/home-manager-option-search)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### Community sources
    # Pre-commit hooks (https://github.com/cachix/git-hooks.nix)
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management (https://github.com/Mic92/sops-nix)
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning (https://github.com/nix-community/disko)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Ephemeral root
    # https://github.com/nix-community/preservation
    preservation.url = "github:nix-community/preservation";

    # Themeing (https://github.com/nix-community/stylix)
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### Personal sources
    # Private secrets repo (https://github.com/MaxBullett/nix-secrets)
    nix-secrets = {
      url = "git+ssh://git@github.com/MaxBullett/nix-secrets.git?ref=main&shallow=1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      # Architectures
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];

      # Custom lib extension
      lib = nixpkgs.lib.extend (
        self: super: {
          custom = import ./lib { inherit (nixpkgs) lib; };
        }
      );

    in
    {
      # Formatter (https://github.com/NixOS/nixfmt)
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Checks
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./checks.nix { inherit inputs system pkgs; }
      );

      # Devshell
      devShells = forAllSystems (
        system:
        import ./devShell.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          checks = self.checks.${system};
        }
      );

      # Overlays
      overlays = import ./overlays { inherit inputs; };

      # Packages
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        nixpkgs.lib.packagesFromDirectoryRecursive {
          callPackage = nixpkgs.lib.callPackageWith pkgs;
          directory = ./pkgs;
        }
      );

      # Hosts
      nixosConfigurations = builtins.listToAttrs (
        map (host: {
          name = host;
          value = nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs outputs lib;
              hostName = host;
              hostUsers = [ ];
            };
            modules = [ ./hosts/${host} ];
          };
        }) (builtins.attrNames (builtins.readDir ./hosts))
      );
    };
}
