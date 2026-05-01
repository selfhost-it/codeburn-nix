# CodeBurn - See where your AI coding tokens go
#
# Built from GitHub source using buildNpmPackage + tsup.
#
# To update:
#   1. Change `version`
#   2. Update `hash` (set to "" and build — nix will tell you the correct hash)
#   3. Update `npmDepsHash` (set to "" and build — nix will tell you the correct hash)
#   4. Refresh the litellm price snapshot pinned in `litellmRaw` (see comment below)
#   5. Run `nix build`

{ lib
, buildNpmPackage
, fetchFromGitHub
, fetchurl
, nodejs_22
}:

let
  version = "0.9.5";

  # Since v0.9.4, `npm run build` invokes `node scripts/bundle-litellm.mjs`,
  # which fetches a JSON snapshot from BerriAI/litellm at build time. Network
  # access is forbidden inside the Nix sandbox, so we vendor the file via a
  # fixed-output `fetchurl` and patch the script to read from the local store
  # path. Pin to a specific commit (not `main`) for reproducibility — refresh
  # on bumps by updating `rev`, setting `hash = "";`, and rebuilding.
  litellmRaw = fetchurl {
    url = "https://raw.githubusercontent.com/BerriAI/litellm/3e1479c0528919bd722b8d4ea6d5c210290ef74b/model_prices_and_context_window.json";
    hash = "sha256-uU10hiITCKW4SAjqJD8328WQoNShCc5cnMsRvX3F/wM=";
  };
in
buildNpmPackage {
  pname = "codeburn";
  inherit version;

  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "v${version}";
    hash = "sha256-54NWcnVXQIDz2JzzFW8SJ+I2Ff6KyumrO3DdrvzuHUE=";
  };

  nodejs = nodejs_22;

  npmDepsHash = "sha256-vcChnFLiuiymqZb4ojvv7a7Cdg4BYYT+ZraTVELEsQ0=";

  # Redirect bundle-litellm.mjs's runtime `fetch()` to read the vendored
  # snapshot from the Nix store. The `if (!res.ok)` check stays as a no-op
  # because we shim `res` to `{ ok: true }`. `--replace-fail` ensures future
  # upstream restructurings of this script break the build loudly instead
  # of silently producing a stale snapshot.
  postPatch = ''
    substituteInPlace scripts/bundle-litellm.mjs \
      --replace-fail \
        "import { writeFileSync, mkdirSync } from 'fs'" \
        "import { writeFileSync, mkdirSync, readFileSync } from 'fs'"
    substituteInPlace scripts/bundle-litellm.mjs \
      --replace-fail \
        "const res = await fetch(LITELLM_URL)" \
        "const res = { ok: true }"
    substituteInPlace scripts/bundle-litellm.mjs \
      --replace-fail \
        "const data = await res.json()" \
        "const data = JSON.parse(readFileSync('${litellmRaw}', 'utf8'))"
  '';

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
