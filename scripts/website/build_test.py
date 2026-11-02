import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from html.parser import HTMLParser

from build import Artist, FALLBACK_IMAGE, REPO, build, image_url, load_artists, plain_text, render


class Head(HTMLParser):
    def __init__(self, page):
        super().__init__()
        self.meta = {}
        self.canonical = None
        self.tags = []
        self.feed(page)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append(tag)
        if tag == "meta":
            self.meta[attrs.get("property") or attrs.get("name")] = attrs.get("content")
        if tag == "link" and attrs.get("rel") == "canonical":
            self.canonical = attrs["href"]


class PreviewTests(unittest.TestCase):
    def test_artist_values_cannot_break_metadata_and_body_stays_identical(self):
        template = (REPO / "website/rudolstadt/index.html").read_text()
        artist = Artist(2026, 67, 'A & B "><script>alert(1)</script>', '"Musik" & mehr', FALLBACK_IMAGE)
        page = render(template, artist)
        head = Head(page)
        self.assertEqual(head.meta["og:title"], f"{artist.name} · Rudolstadt-Festival 2026")
        self.assertEqual(head.meta["og:description"], artist.description)
        self.assertEqual(head.meta["og:url"], artist.url)
        self.assertEqual(head.canonical, artist.url)
        self.assertEqual(head.meta["twitter:image"], FALLBACK_IMAGE)
        self.assertNotIn("script", head.tags)
        self.assertEqual(template.split("<body>")[1], page.split("<body>")[1])

    def test_description_markup_entities_and_word_boundaries(self):
        self.assertEqual(
            plain_text('<p>Folk &amp; Tanz</p><p>für alle<br>heute</p><script>secret()</script>'),
            "Folk & Tanz für alle heute",
        )

    def test_archive_and_modern_images_are_absolute_encoded_and_have_fallback(self):
        self.assertEqual(
            image_url({"image": "A Filetta©.jpg"}, 2023, False),
            "https://www.rudolstadt-festival.de/data/2023/images/full/A%20Filetta%C2%A9.jpg",
        )
        self.assertEqual(
            image_url({"img_full": "/assets/images/x/A%C2%A9.jpg"}, 2026, True),
            "https://www.rudolstadt-festival.de/assets/images/x/A%C2%A9.jpg",
        )
        self.assertEqual(image_url({}, 2026, True), FALLBACK_IMAGE)
        self.assertEqual(image_url({"image": "Mandolinenorchester.jpg"}, 2019, False), FALLBACK_IMAGE)
        self.assertEqual(image_url({"img_full": "/assets/images/a/AAAPLATZHALTER-jj406147npwtqwg.jpg"}, 2026, True), FALLBACK_IMAGE)
        with self.assertRaises(ValueError):
            image_url({"img_full": "https://unexpected.example/image.jpg"}, 2026, True)

    def test_full_build_removes_stale_pages_preserves_associations_and_fails_safely(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            source = repo / "website"
            (source / "rudolstadt").mkdir(parents=True)
            (source / "rudolstadt/index.html").write_text((REPO / "website/rudolstadt/index.html").read_text())
            (source / ".well-known").mkdir()
            (source / ".well-known/assetlinks.json").write_text("[]")
            (source / "README.md").write_text("Not public")
            data = repo / "shared/src/commonMain/resources/FestivalBackup"
            data.mkdir(parents=True)
            path = data / "2026_rudolstadt_data.json"
            records = [{"id": 67, "name": 'Wanderlust &amp; Freunde', "description_de": "<p>Musik</p>"},
                       {"id": 23, "name": "Hidden", "hide_artist": True}]
            path.write_text(json.dumps({"artists": records}))
            with contextlib.redirect_stdout(io.StringIO()):
                artists = build(repo)
                self.assertEqual([(a.id, a.name) for a in artists], [(67, "Wanderlust & Freunde")])
                output = repo / "artifacts/website"
                self.assertTrue((output / "rudolstadt/2026/artists/67.html").exists())
                self.assertFalse((output / "rudolstadt/2026/artists/23.html").exists())
                self.assertEqual((output / ".well-known/assetlinks.json").read_text(), "[]")
                self.assertFalse((output / "README.md").exists())
                self.assertTrue((output / "rudolstadt/404.html").exists())
                records[0]["id"] = 68
                path.write_text(json.dumps({"artists": records}))
                build(repo)
                self.assertFalse((output / "rudolstadt/2026/artists/67.html").exists())
                path.write_text(json.dumps({"artists": [records[0], records[0]]}))
                with self.assertRaises(ValueError):
                    build(repo)
                self.assertTrue((output / "rudolstadt/2026/artists/68.html").exists())

    def test_real_data_has_distinct_artist_previews_for_every_bundled_year(self):
        artists = load_artists(REPO / "shared/src/commonMain/resources/FestivalBackup")
        self.assertEqual({a.year for a in artists}, {2019, 2022, 2023, 2024, 2025, 2026})
        wanderlust = next(a for a in artists if a.year == 2026 and a.id == 67)
        profolk = next(a for a in artists if a.year == 2026 and a.id == 23)
        self.assertIn("Wanderlust", wanderlust.name)
        self.assertEqual(profolk.name, "Profolk-Session")
        self.assertNotEqual(wanderlust.image, profolk.image)
        self.assertNotEqual(wanderlust.image, FALLBACK_IMAGE)


if __name__ == "__main__":
    unittest.main()
