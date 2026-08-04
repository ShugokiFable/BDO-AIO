from __future__ import annotations

import pathlib
import tempfile
import unittest

from vanilla_restore import AIO_BACKUP_NAME, find_backups, human, orphan_paz


class OrphanSelectionTests(unittest.TestCase):
    """A PAZ is deletable only if it is unreferenced AND above the vanilla ceiling."""

    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-test-"))

    def make(self, *numbers: int) -> None:
        for n in numbers:
            (self.dir / f"PAD{n:05d}.PAZ").write_bytes(b"x")

    def test_deletes_only_the_injected_high_numbers(self) -> None:
        self.make(1, 2, 500, 11398, 61337, 61338)
        keep = {1, 2, 11398}
        got = [p.name for p in orphan_paz(self.dir, keep)]
        self.assertEqual(got, ["PAD61337.PAZ", "PAD61338.PAZ"])

    def test_never_deletes_unreferenced_vanilla_archives(self) -> None:
        """Vanilla ships archives no meta block points at; those must survive."""
        self.make(500, 9000, 11398)
        keep = {11398}
        self.assertEqual(orphan_paz(self.dir, keep), [])

    def test_no_keep_set_deletes_nothing(self) -> None:
        self.make(61337)
        self.assertEqual(orphan_paz(self.dir, set()), [])

    def test_ignores_non_paz_files(self) -> None:
        self.make(61337)
        (self.dir / "pad00000.meta").write_bytes(b"x")
        (self.dir / "pad00000.meta.backup").write_bytes(b"x")
        (self.dir / "Meta Injector.exe").write_bytes(b"x")
        got = [p.name for p in orphan_paz(self.dir, {11398})]
        self.assertEqual(got, ["PAD61337.PAZ"])

    def test_matches_lowercase_paz_names(self) -> None:
        (self.dir / "pad61337.paz").write_bytes(b"x")
        self.assertEqual([p.name for p in orphan_paz(self.dir, {11398})], ["pad61337.paz"])


class BackupOrderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-test-"))

    def test_oldest_backup_wins(self) -> None:
        import os, time

        older = self.dir / "pad00000[2026-08-01][1].meta.backup"
        newer = self.dir / "pad00000[2026-08-03][2].meta.backup"
        older.write_bytes(b"a")
        newer.write_bytes(b"b")
        now = time.time()
        os.utime(older, (now - 10000, now - 10000))
        os.utime(newer, (now, now))
        self.assertEqual(find_backups(self.dir)[0].name, older.name)

    def test_aio_snapshot_is_preferred_over_injector_backups(self) -> None:
        (self.dir / "pad00000[2026-08-01][1].meta.backup").write_bytes(b"a")
        (self.dir / AIO_BACKUP_NAME).write_bytes(b"v")
        self.assertEqual(find_backups(self.dir)[0].name, AIO_BACKUP_NAME)

    def test_no_backups_is_empty_not_an_error(self) -> None:
        self.assertEqual(find_backups(self.dir), [])


class HumanTests(unittest.TestCase):
    def test_units(self) -> None:
        self.assertEqual(human(1024 ** 2), "1.0 MB")
        self.assertTrue(human(2 * 1024 ** 3).endswith("GB"))


if __name__ == "__main__":
    unittest.main()
