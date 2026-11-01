import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("export_native", Path(__file__).with_name("export_native_screenshots.py"))
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


class AttachmentExportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name) / "attachments"
        self.source.mkdir()
        self.output = Path(self.temporary.name) / "output"
        self.attachments = []
        for index, screen in enumerate(exporter.SCREENS):
            filename = f"attachment-{index}"
            (self.source / filename).write_bytes(b"\x89PNG\r\n\x1a\n")
            self.attachments.append({"suggestedHumanReadableName": f"native-en-{screen}_0_UUID.png", "exportedFileName": filename})

    def write_manifest(self):
        (self.source / "manifest.json").write_text(json.dumps([{"attachments": self.attachments}]))

    def test_named_attachments_preserve_existing_publisher_layout(self):
        self.write_manifest()
        exporter.export(self.source, self.output, ["en"], "iPhone_17", "capture")
        self.assertEqual({p.stem for p in (self.output / "en/iPhone_17/capture").glob("*.png")}, set(exporter.SCREENS))

    def test_incomplete_capture_never_publishes_partial_set(self):
        self.attachments.pop()
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            exporter.export(self.source, self.output, ["en"], "iPhone_17", "capture")
        self.assertFalse(self.output.exists())

    def test_duplicate_scene_fails_instead_of_picking_a_retry(self):
        self.attachments.append(self.attachments[0])
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            exporter.export(self.source, self.output, ["en"], "iPhone_17", "capture")


if __name__ == "__main__":
    unittest.main()
