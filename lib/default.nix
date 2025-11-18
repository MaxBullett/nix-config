{
  inputs,
  lib,
  self,
}:
let
  inherit (lib)
    attrNames
    concatMap
    filterAttrs
    hasSuffix
    mapAttrsToList
    optionals
    pathExists
    sort
    ;
in
rec {
  # Returns path relative to flake root
  relativeToRoot = path: self + "/${path}";

  # Get all normal (non-system) users from config
  getNormalUsers = config: filterAttrs (_: user: user.isNormalUser or false) config.users.users;

  # Discover domain modules based on repository layout
  domainModulePaths =
    let
      domainsRoot = relativeToRoot "domains";
      domainEntries = builtins.readDir domainsRoot;
      domainDirectories = filterAttrs (_: type: type == "directory") domainEntries;
      modulePathsForDomain =
        domain:
        let
          domainPath = "${domainsRoot}/${domain}";
          relDomainPath = "domains/${domain}";
          entries = builtins.readDir domainPath;
          moduleFiles = mapAttrsToList (
            name: _: if hasSuffix ".nix" name && name != "default.nix" then "${relDomainPath}/${name}" else null
          ) (filterAttrs (_: type: type == "regular") entries);
          moduleDirectories = mapAttrsToList (
            name: _:
            let
              relModulePath = "${relDomainPath}/${name}/default.nix";
            in
            if builtins.pathExists (relativeToRoot relModulePath) then relModulePath else null
          ) (filterAttrs (_: type: type == "directory") entries);
        in
        builtins.filter (path: path != null) (moduleFiles ++ moduleDirectories);
      unsortedPaths = concatMap modulePathsForDomain (attrNames domainDirectories);
    in
    sort (a: b: a < b) unsortedPaths;

  # Expand relative module paths into importable Nix modules
  autoDomainImports = builtins.map relativeToRoot domainModulePaths;

  # Discover host names from the directory structure (DDD‑compliant infra concern)
  listHostNames =
    let
      entries = builtins.readDir (self + "/compositions/hosts");
      dirs = lib.filterAttrs (_: t: t == "directory") entries;
    in
    builtins.attrNames dirs;

  # Map host → system (customize per host if needed)
  systemForHost = host: "x86_64-linux";

  # Standard module stack for each host
  mkHostModules =
    host: extraModules:
    let
      domainModules =
        autoDomainImports
        ++ [
          inputs.home-manager.nixosModules.home-manager
          inputs.disko.nixosModules.disko
        ]
        ++ optionals (pathExists (relativeToRoot "compositions/hosts/${host}/hardware.nix")) [
          (relativeToRoot "compositions/hosts/${host}/hardware.nix")
        ]
        ++ optionals (pathExists (relativeToRoot "compositions/hosts/${host}/disko.nix")) [
          (relativeToRoot "compositions/hosts/${host}/disko.nix")
        ];
    in
    domainModules ++ extraModules;

  # Expand a host’s user list into importable modules
  usersForHost =
    host: users:
    lib.concatMap (
      u:
      let
        base = relativeToRoot "compositions/users/${u}/default.nix";
        perHost = relativeToRoot "compositions/users/${u}/hosts/${host}.nix";
      in
      (if pathExists base then [ base ] else [ ]) ++ (if pathExists perHost then [ perHost ] else [ ])
    ) users;
}
