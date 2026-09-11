# codeburn-nix

Always up-to-date Nix package for [CodeBurn](https://github.com/getagentseal/codeburn) — an interactive terminal dashboard that monitors AI coding token consumption across Claude Code, Codex, Cursor, OpenCode and more.

> **Beta**: This project is under active development by a solo maintainer and may break between updates. Use at your own risk. Contributions are welcome — feel free to open issues or submit pull requests!

## Why this package?

CodeBurn is not yet packaged in nixpkgs. This flake lets you:

1. **Always have the latest version** — update as soon as a new release drops
2. **Declarative installation** — managed in your NixOS or Home Manager config
3. **Reproducible builds** — built from source via `buildNpmPackage` + tsup

## Project Structure

| File | Purpose |
|---|---|
| `flake.nix` | Flake definition: inputs (nixpkgs, flake-utils), overlay, packages, app |
| `package.nix` | Build recipe: fetches the GitHub source, runs `tsup` to bundle, lets `buildNpmPackage` install bin |
| `default.nix` | Non-flake entry point (NUR-compatible) |
| `flake.lock` | Pinned inputs |
| `update.sh` | Deterministic local update workflow (no LLM required) |
| `.gitignore` | Excludes Nix build artifacts and editor files |

## Quick Start

```bash
# Run directly without installing
nix run github:selfhost-it/codeburn-nix

# Install to your profile
nix profile install github:selfhost-it/codeburn-nix
```

## NixOS / Home Manager Integration

### Add to your flake inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    codeburn = {
      url = "github:selfhost-it/codeburn-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

### Apply the overlay

```nix
{
  nixpkgs.overlays = [
    codeburn.overlays.default
  ];
}
```

### Add to your packages

NixOS (`configuration.nix`):

```nix
environment.systemPackages = with pkgs; [
  codeburn
];
```

Home Manager (`home.nix`):

```nix
home.packages = with pkgs; [
  codeburn
];
```

## Building Locally

```bash
git clone git@github.com:selfhost-it/codeburn-nix.git
cd codeburn-nix
nix build .

# Test
./result/bin/codeburn --version

# Or run directly
nix run .
```

## Updating to a new CodeBurn version

CodeBurn ships two release streams in the same repo: the CLI (tags like `v0.9.1`)
and the macOS menubar app (tags like `mac-v0.9.0`). This flake tracks the **CLI
tags only** — make sure to ignore `mac-*` tags when bumping.

1. Change `version` in `package.nix` (e.g. `"0.9.2"`)

2. Set `hash = "";` in `package.nix` and run:
   ```bash
   nix build .
   ```
   The build will fail and print the correct hash. Paste it back.

3. Set `npmDepsHash = "";` in `package.nix` and run:
   ```bash
   nix build .
   ```
   Again, paste the hash from the error message.

4. Set `dashDeps.hash = "";` and run `nix build .` again to obtain the
   dashboard's separate npm dependency hash. Paste the reported hash back.

5. Refresh `litellmRaw` to a specific BerriAI/litellm commit, update its URL,
   set its `hash = "";`, and rebuild to obtain the fixed-output hash. Never pin
   this snapshot to a mutable branch such as `main`.

6. Run `nix build .` again, verify `./result/bin/codeburn --version`, then
   commit and push.

The deterministic updater performs all four hash updates without an LLM:

```bash
./update.sh --check              # report whether an update is available
./update.sh --dry-run            # resolve and validate an update without changing files or building
./update.sh --no-push            # update, build, verify and commit locally
./update.sh --version 0.9.24     # target an explicit version
./update.sh                      # update, build, verify, commit and push
```

## Technical Details

- **Source**: Built from the [getagentseal/codeburn](https://github.com/getagentseal/codeburn) GitHub repo
- **Builder**: `buildNpmPackage` with the root npm dependencies and a separate
  `dashDeps` fixed-output cache for the React dashboard in `dash/`
- **Price data**: the build reads a `litellmRaw` snapshot pinned to an immutable
  BerriAI/litellm commit instead of fetching the mutable file during the sandboxed build
- **Runtime**: Node.js 22
- **Native deps**: none (the upstream `mac/` SwiftUI app is not packaged here)
- **Binary**: `codeburn` (at `$out/bin/codeburn`)
- The package is a single ESM module (`"type": "module"` in `package.json`); tsup keeps `dependencies` external and emits `dist/cli.js` with a `#!/usr/bin/env node` banner
- `buildNpmPackage`'s default install phase runs `npm pack` (which respects `files: ["dist"]`) and then `npm install --global` into `$out`, producing both the bin wrapper and the patched shebang
- `buildNpmPackage` also runs `patchShebangs` on the install prefix, so the banner inside `dist/cli.js` is rewritten to point at the exact `nodejs_22` derivation

## License

CodeBurn is licensed under [MIT](https://github.com/getagentseal/codeburn/blob/main/LICENSE) by AgentSeal.

---

Maintained by [self-host.it](https://self-host.it)
