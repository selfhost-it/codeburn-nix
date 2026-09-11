#!/usr/bin/env python3
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from update_common import (  # noqa: E402
    Profile as BaseProfile,
    Target,
    UpdateError,
    Version,
    learn_hashes,
    main,
    package_version,
    select_release,
    set_named_hash,
    set_package_version,
    set_source_hash,
    source_hash,
    validate_sri,
)


class Profile(BaseProfile):
    name = "CodeBurn"
    files = ("package.nix",)
    binary = "codeburn"
    repository = "getagentseal/codeburn"

    def current_version(self, root: Path) -> Version:
        return package_version(root)

    def discover(self, ctx, requested: Version | None) -> Target:
        version = select_release(ctx, self.repository, requested, exclude_prefixes=("mac-",))
        commits = ctx.http_json(
            "https://api.github.com/repos/BerriAI/litellm/commits"
            "?path=model_prices_and_context_window.json&per_page=1"
        )
        if not isinstance(commits, list) or len(commits) != 1 or not isinstance(commits[0], dict):
            raise UpdateError("LiteLLM commits API returned an unexpected schema")
        revision = commits[0].get("sha")
        if not isinstance(revision, str) or not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise UpdateError("LiteLLM commits API returned an invalid commit")
        return Target(version, revision)

    def prepare(self, ctx, target: Target) -> None:
        set_package_version(ctx, target.version)
        set_source_hash(ctx, source_hash(ctx, self.repository, target.version))

        revision = target.payload
        litellm_url = (
            "https://raw.githubusercontent.com/BerriAI/litellm/"
            f"{revision}/model_prices_and_context_window.json"
        )
        litellm_hash = ctx.prefetch(litellm_url, unpack=False)
        validate_sri(litellm_hash, "sha256")
        ctx.replace_one(
            "package.nix",
            r'(url\s*=\s*"https://raw\.githubusercontent\.com/BerriAI/litellm/)[0-9a-f]{40}(/model_prices_and_context_window\.json";)',
            rf"\g<1>{revision}\g<2>",
        )
        ctx.replace_one(
            "package.nix",
            r'(litellmRaw\s*=\s*fetchurl\s*\{.*?\n\s*hash\s*=\s*)"[^"]*";',
            rf'\g<1>"{litellm_hash}";',
            flags=re.DOTALL,
        )

        def set_dash(value: str) -> None:
            ctx.replace_one(
                "package.nix",
                r'(dashDeps\s*=\s*fetchNpmDeps\s*\{.*?\n\s*hash\s*=\s*)"[^"]*";',
                rf'\g<1>"{value}";',
                flags=re.DOTALL,
            )

        learn_hashes(
            ctx,
            {
                "npmDepsHash": (
                    f"codeburn-{target.version}-npm-deps",
                    lambda value: set_named_hash(ctx, "npmDepsHash", value),
                ),
                "dashDeps.hash": (f"codeburn-{target.version}-dash-npm-deps", set_dash),
            },
        )

    def commit_subject(self, target: Target) -> str:
        return f"Update CodeBurn to v{target.version}"


if __name__ == "__main__":
    raise SystemExit(main(Profile()))
