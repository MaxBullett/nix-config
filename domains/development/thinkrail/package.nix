# ThinkRail has no nixpkgs package, so this builds it from source, adapted from
# https://github.com/nickgarvey/homelab-nixpkgs/blob/main/thinkrail/flake.nix
# for this repo's single-system (x86_64-linux) domain-local callPackage layout.
#
# --- Updating the pinned revision -------------------------------------------
# "Track latest master" means "re-pin `rev` to a concrete commit SHA now and then" --
# fetchFromGitHub needs a fixed rev to be reproducible, it cannot float on a branch
# ref. Whenever `rev` changes, both hashes below usually need to be refreshed too.
# Procedure:
#   1. git ls-remote https://github.com/JetBrains/thinkrail HEAD
#      Put that SHA in `rev`, update the `version` date.
#   2. Set both `hash` and `nodeModulesHash` to `lib.fakeHash`, build just the
#      nodeModules output (fast -- doesn't invoke the full compile):
#        nix build --impure -L --expr \
#          '(builtins.getFlake (toString ./.)).nixosConfigurations.odysseus.pkgs.callPackage ./domains/development/thinkrail/package.nix { } .nodeModules'
#      This fails first on the fetchFromGitHub hash. Copy "got: sha256-..." into `hash`.
#   3. Re-run the same command. The fetch now succeeds and bun install runs, then
#      fails on the nodeModules FOD hash. Copy "got: sha256-..." into `nodeModulesHash`.
#   4. Re-run once more -- should now build cleanly.
#   5. Build the full package (drop the `.nodeModules` selector) to confirm
#      `bun run build:binary` still succeeds against the new revision.
# -----------------------------------------------------------------------------
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  nodejs_22,
  git,
  makeWrapper,
  zenity,
  procps,
  xdg-utils,
}:
let
  version = "0-unstable-2026-09-08"; # date of the pinned commit below

  src = fetchFromGitHub {
    owner = "JetBrains";
    repo = "thinkrail";
    rev = "51eb4948feec4be364307289a7cb1a99b0088074"; # latest master as of 2026-09-08
    hash = "sha256-eEGW74r+5A1vyiWOnRRU8Gh5OBdWzCcINA6cCCeyucw=";
  };

  nodeModulesHash = "sha256-Jedilfc1qo+UrYrEtHpXL4EMYfEhuD1+491T7JAQ6LQ=";

  # bun install for the whole workspace as a fixed-output derivation so the real
  # build can stay offline. Bun's isolated layout is a tree of relative symlinks
  # under node_modules/.bun plus one node_modules per workspace member, captured
  # as those directories at their original paths.
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "thinkrail-node-modules";
    inherit version src;
    nativeBuildInputs = [ bun ];
    dontConfigure = true;
    dontFixup = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      bun install --frozen-lockfile --ignore-scripts --no-progress
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      find . -type d -name node_modules -prune -print0 |
        while IFS= read -r -d "" dir; do
          mkdir -p "$out/$(dirname "$dir")"
          cp -a "$dir" "$out/$dir"
        done
      runHook postInstall
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = nodeModulesHash;
  };

  # git: worktree ops; zenity: folder-picker dialog (falls back to kdialog, else
  # reports neither exists); procps (pgrep): detect a busy terminal tab before
  # closing; xdg-utils (xdg-open): open browser on startup unless --no-open.
  # gh/editors/JetBrains central stay out -- probed via Bun.which.
  runtimeDeps = [
    git
    nodejs_22
    zenity
    procps
    xdg-utils
  ];
in
stdenv.mkDerivation {
  pname = "thinkrail";
  inherit version src;

  nativeBuildInputs = [
    bun
    nodejs_22
    git
    makeWrapper
  ];

  configurePhase = ''
    runHook preConfigure
    cp -a ${nodeModules}/. .
    chmod -R u+w .
    # vendored CLIs are `#!/usr/bin/env node` scripts; neither /usr/bin/env nor
    # an unpatched node exists in the sandbox.
    find . -type d -name node_modules -prune -print0 |
      while IFS= read -r -d "" dir; do
        patchShebangs --build "$dir"
      done
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    export TURBO_TELEMETRY_DISABLED=1
    export TURBO_NO_UPDATE_NOTIFIER=1
    export DO_NOT_TRACK=1
    bun run build:binary
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 apps/cli/dist/thinkrail $out/libexec/thinkrail/thinkrail
    makeWrapper $out/libexec/thinkrail/thinkrail $out/bin/thinkrail \
      --suffix PATH : ${lib.makeBinPath runtimeDeps}
    runHook postInstall
  '';

  # compiled artifact is a bun runtime with the bundle appended; strip discards
  # the payload and breaks it ("Failed to open executable as zip").
  dontStrip = true;

  # Lets the node_modules layer be built/iterated on independently of the
  # slower full `bun run build:binary` step (see header comment).
  passthru = {
    inherit nodeModules;
  };

  meta = {
    description = "Desktop/browser IDE host that runs the pi coding agent over git worktrees";
    homepage = "https://thinkrail.ai/";
    license = lib.licenses.asl20; # verify against upstream LICENSE when pinning
    mainProgram = "thinkrail";
    platforms = [ "x86_64-linux" ];
  };
}
