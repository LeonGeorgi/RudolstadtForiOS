import json
import pathlib
import tempfile
import unittest

from import_festival_archive import records, snapshot


class ArchiveImportTests(unittest.TestCase):
    def test_descriptions_keep_continuation_lines(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            (path / "artists.dat").write_text(
                "1~1~0~Artist~DEU~~~~photo.jpg~First line\nSecond line~English\n"
                + "~".join(["2", "3", "0", "Other", "", "", "", "", "", "", ""]) + "\n",
                encoding="utf-8")

            result = records(path, "artists", 11)

            self.assertEqual(len(result), 2)
            self.assertEqual(result[0][9], "First line\nSecond line")
            self.assertEqual(result[0][10], "English")

    def test_malformed_export_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            (path / "events.dat").write_text("<!DOCTYPE html>Start page\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                records(path, "events", 6)

    def write_modern_fixture(self, directory):
        records = {
            "artists": [dict(id=7, category="concert", hide_artist=True, name="Artist", country="ENG",
                             website="", video="https://www.youtube.com/watch?v=abc", facebook="",
                             instagram="https://www.instagram.com/example/", img_thumb="/assets/images/3/photo.jpg",
                             img_full="/assets/images/9/photo.jpg", description_de="Deutsch", description_en="English")],
            "areas": [dict(id=1, title="Park", title_en="Park")],
            "stages": [dict(id=2, title="Bühne", title_en="Stage", description=None, description_en=None,
                            lat=None, lon=None, area=1, category="cityticket", map_number=3)],
            "tags": [dict(id=6, title="Straßenmusik", title_en="Buskers")],
            "events": [dict(id=42, start=dict(date="2025-07-05 00:30:00.000000", timezone="Europe/Berlin"),
                            day="05.07.2025", time="00:30", stage=2, artist=7, tags=[6])]
        }
        for name, values in records.items():
            (directory / f"{name}.json").write_text(json.dumps(values), encoding="utf-8")

    def test_modern_assets_preserve_ids_visibility_links_dates_and_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            self.write_modern_fixture(path)
            result = snapshot(path, 2025, "https://example.com/app-release", "12.3.0")
            artist = result["artists"][0]
            self.assertEqual((artist["id"], artist["type"], artist["hidden"]), (7, 3, True))
            self.assertEqual(artist["instagram"], "https://www.instagram.com/example/")
            self.assertEqual(artist["thumbURL"], "/assets/images/3/photo.jpg")
            self.assertEqual(result["events"][0], dict(id=42, day=5, time="00:30", stage=2, artist=7, tags=[6]))
            self.assertEqual(result["stages"][0]["type"], 2)
            self.assertEqual(result["sourceRelease"], "12.3.0")
            self.assertEqual(result["sources"]["artists"]["url"], "https://example.com/app-release")
            self.assertEqual(len(result["sources"]["artists"]["sha256"]), 64)

    def test_modern_wrong_year_or_missing_reference_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            self.write_modern_fixture(path)
            with self.assertRaises(ValueError):
                snapshot(path, 2024)
            events_file = path / "events.json"
            events = json.loads(events_file.read_text())
            events[0]["artist"] = 999
            events_file.write_text(json.dumps(events))
            with self.assertRaisesRegex(ValueError, "Missing artist"):
                snapshot(path, 2025)


if __name__ == "__main__":
    unittest.main()
