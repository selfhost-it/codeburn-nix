# CodeBurn - See where your AI coding tokens go
#
# Built from GitHub source using buildNpmPackage + tsup.
#
# To update:
#   1. Change `version`
#   2. Update `hash` (set to "" and build — nix will tell you the correct hash)
#   3. Update `npmDepsHash` (set to "" and build — nix will tell you the correct hash)
#   4. Run `nix build`

{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs_22
}:

let
  version = "0.9.1";
in
buildNpmPackage {
  pname = "codeburn";
  inherit version;

  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "v${version}";
    hash = "sha256-hYFXlrcWACmRlF1OWM9Mh33THfuMdKAPqqQpdzSTEzw=";
  };

  nodejs = nodejs_22;

  npmDepsHash = "sha256-IQT3SNrWoxbdxHEPGwmUhLNPXDQpPKmsnXRCfytBasI=";

  # tsup bundles src/cli.ts -> dist/cli.js with a #!/usr/bin/env node banner.
  # The package.json `bin` field points to dist/cli.js, and `files: ["dist"]`
  # means npm pack ships only that. buildNpmPackage's default install phase
  # (npm pack + npm install --global into $out) handles the bin wrapper and
  # patches the shebang to the nodejs derivation in the closure.
  npmBuildScript = "build";

  meta = with lib; {
    description = "See where your AI coding tokens go - by task, tool, model, and project";
    homepage = "https://github.com/getagentseal/codeburn";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "codeburn";
  };
}
