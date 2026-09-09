from __future__ import annotations

import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

from tools import export_stl


class StlBuildTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.stls = self.root / "STLs"
        self.target = self.stls / "nested folder" / "[a]_bracket_x2.stl"
        self.cache = self.root / "obj" / "STLs"
        self.manifest = self.root / "printed.json"
        self.identity = "11111111-2222-3333-4444-555555555555"
        self.record = {"id": self.identity, "path": str(self.target), "component_id": "fusion-id",
                       "component_name": "Bracket", "bodies": ["Body1", "Body 2"], "body_hashes": ["a", "b"]}
        self.save_manifest()
        self.mesh = b"test STL".ljust(80, b"\0") + struct.pack("<I", 1) + bytes(50)
        self.guard = self.enterContext(patch.object(export_stl, "check_export_support"))
        self.export = self.enterContext(patch.object(export_stl, "export_stl", side_effect=self.write_export))

    def save_manifest(self):
        self.manifest.write_text(json.dumps({self.identity + ".json": self.record}), encoding="utf-8")

    def write_export(self, payload, target, base_url):
        self.assertEqual(payload, {"format": "stl", "component": "fusion-id",
                                   "body": ["Body1", "Body 2"], "orient": "Build Plate"})
        target.write_bytes(self.mesh)

    def build(self):
        return export_stl.build(self.manifest, self.cache, self.stls, "http://localhost:5000")

    def test_exports_group_with_explicit_orientation_and_reuses_unchanged_cache(self):
        self.assertEqual(self.build(), (1, 1))
        before = self.target.stat().st_mtime_ns
        self.assertEqual(self.target.read_bytes(), self.mesh)
        self.assertEqual(self.build(), (0, 0))
        self.assertEqual(self.target.stat().st_mtime_ns, before)
        self.assertEqual(self.export.call_count, 1)

    def test_missing_published_file_is_restored_without_fusion_export(self):
        self.build()
        self.target.unlink()
        self.assertEqual(self.build(), (0, 1))
        self.assertEqual(self.export.call_count, 1)
        self.assertEqual(self.target.read_bytes(), self.mesh)

    def test_changed_geometry_or_corrupt_cache_requires_fresh_export(self):
        self.build()
        self.record["body_hashes"][0] = "changed"
        self.save_manifest()
        self.assertEqual(self.build(), (1, 0))
        (self.cache / (self.identity + ".stl")).write_bytes(b"corrupt")
        self.assertEqual(self.build(), (1, 0))
        self.assertEqual(self.export.call_count, 3)

    def test_failed_or_invalid_export_preserves_published_file_and_success_stamp(self):
        self.build()
        stamp = self.cache / (self.identity + ".export.json")
        old_stamp = stamp.read_bytes()
        self.record["body_hashes"][0] = "changed"
        self.save_manifest()
        for failure in (True, False):
            def fail(payload, target, base_url):
                target.write_bytes(b"partial")
                if failure:
                    raise export_stl.fusion_cli.CliError("Fusion export failed")
            self.export.side_effect = fail
            with self.subTest(failure=failure), self.assertRaises((ValueError, export_stl.fusion_cli.CliError)):
                self.build()
            self.assertEqual(self.target.read_bytes(), self.mesh)
            self.assertEqual(stamp.read_bytes(), old_stamp)
            self.assertEqual(list(self.cache.glob("tmp*")), [])

    def test_rejects_output_outside_stl_tree_before_export(self):
        self.record["path"] = str(self.root / "outside.stl")
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, "must stay inside"):
            self.build()
        self.export.assert_not_called()
        self.assertFalse(self.cache.exists())

    def test_old_server_fails_before_publishing_any_stls(self):
        self.guard.side_effect = ValueError("restart the add-in")
        with self.assertRaisesRegex(ValueError, "restart the add-in"):
            self.build()
        self.export.assert_not_called()
        self.assertFalse(self.target.exists())


class StlSelectionTests(unittest.TestCase):
    def setUp(self):
        self.components = {
            "bracket-id": {
                "id": "bracket-id",
                "name": "Bracket",
                "occurrences": [{}, {}],
                "bodies": [
                    {"name": "Mount", "hash": "mount-hash", "material": export_stl.ACCENT_MATERIAL},
                    {"name": "Body1", "hash": "body-hash", "material": export_stl.BASE_MATERIAL},
                ],
            },
            "other-id": {
                "id": "other-id",
                "name": "Other",
                "occurrences": [{}],
                "bodies": [
                    {"name": "Body1", "hash": "other-hash", "material": export_stl.BASE_MATERIAL},
                ],
            },
        }

    def test_selects_unique_body_and_validates_count_and_color(self):
        record = export_stl.select_record(
            self.components, Path("STLs/Parts/[a]_mount_x2.stl"), ["Mount"]
        )
        self.assertEqual(record["component_name"], "Bracket")
        self.assertEqual(record["bodies"], ["Mount"])

    def test_ambiguous_body_requires_component_name(self):
        with self.assertRaisesRegex(ValueError, "not unique.*Bracket, Other"):
            export_stl.select_record(self.components, Path("STLs/body_x2.stl"), ["Body1"])
        record = export_stl.select_record(
            self.components, Path("STLs/body_x2.stl"), ["Body1"], "Bracket"
        )
        self.assertEqual(record["component_id"], "bracket-id")

    def test_reports_count_and_color_errors_together(self):
        with self.assertRaisesRegex(ValueError, r"expected _x2.*requires the exact \[a\]_"):
            export_stl.select_record(self.components, Path("STLs/mount.stl"), ["Mount"])

    def test_rejects_x1_suffix_and_base_color_marker(self):
        with self.assertRaisesRegex(ValueError, "no _xN suffix.*must not contain"):
            export_stl.select_record(
                self.components, Path("STLs/[a]_body_x1.stl"), ["Body1"], "Other"
            )


if __name__ == "__main__":
    unittest.main()
