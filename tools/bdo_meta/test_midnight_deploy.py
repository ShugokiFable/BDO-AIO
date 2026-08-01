from __future__ import annotations

import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


class MidnightDeployTests(unittest.TestCase):
    def test_yes_mode_never_reads_stdin(self) -> None:
        source = pathlib.Path(__file__).parents[2] / "pack" / "midnight_xyzw" / "midnight_xyzw.py"
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            pack = root / "pack"
            script_dir = pack / "midnight_xyzw"
            script_dir.mkdir(parents=True)
            shutil.copy2(source, script_dir / source.name)
            for name in ("_00_suzu_nude", "_00_thegreatsage_nude"):
                (script_dir / name).mkdir()
            underwear = script_dir / "_00_remove_underwear" / "_female"
            underwear.mkdir(parents=True)
            (underwear / "fixture.txt").write_text("ok", encoding="utf-8")
            (pack / "Meta Injector.exe").write_bytes(b"")
            (pack / "PartCutGen.exe").write_bytes(b"")
            paz = root / "PAZ"
            paz.mkdir()
            (paz / "pad00000.meta").write_bytes(b"")

            result = subprocess.run(
                [sys.executable, str(script_dir / source.name), "-g", "F", "-a", "U", "--no-xyzw", "--yes", str(paz)],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=10,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("continuing without another prompt", result.stdout)
            self.assertTrue((paz / "files_to_patch" / "_midnight_xyzw" / "_00_remove_underwear" / "_female" / "fixture.txt").is_file())


if __name__ == "__main__":
    unittest.main()
