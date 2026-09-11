import base64
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

import sys
sys.dont_write_bytecode = True
SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import update_common as common  # noqa: E402

spec = importlib.util.spec_from_file_location("codeburn_update_profile", SCRIPTS / "update.py")
profile_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile_module)


def sri(byte):
    return "sha256-" + base64.b64encode(bytes([byte]) * 32).decode()


class ProfileTests(unittest.TestCase):
    def test_prepare_refreshes_all_three_dependency_hashes_and_litellm_pin(self):
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            shutil.copy2(Path(__file__).resolve().parents[1] / "package.nix", work / "package.nix")
            ctx = common.Context(work, work)
            ctx.prefetch = lambda _url, unpack: sri(3)

            def learn(_ctx, setters, _attr="."):
                for index, (_name, (_hint, setter)) in enumerate(setters.items(), 4):
                    setter(sri(index))

            revision = "a" * 40
            target = common.Target(common.Version.parse("0.9.25"), revision)
            with mock.patch.object(profile_module, "source_hash", return_value=sri(1)), mock.patch.object(profile_module, "learn_hashes", side_effect=learn):
                profile_module.Profile().prepare(ctx, target)
            text = (work / "package.nix").read_text()
            for expected in (sri(1), sri(3), sri(4), sri(5), revision):
                self.assertIn(expected, text)
            self.assertIn('version = "0.9.25";', text)


if __name__ == "__main__":
    unittest.main()
