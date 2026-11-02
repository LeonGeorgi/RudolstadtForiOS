#!/usr/bin/env python3
"""Generate static artist link metadata from the app's bundled festival data.

Python 3.10+, standard library only. No network requests or app build required.
"""

from dataclasses import dataclass
from html import escape, unescape
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import tempfile
from urllib.parse import quote, urljoin, urlsplit, urlunsplit


SITE = "https://festival.leongeorgi.de"
FESTIVAL = "https://www.rudolstadt-festival.de"
FALLBACK_IMAGE = f"{SITE}/rudolstadt/app-icon.png"
PLACEHOLDERS = {"aaaplatzhalter-jj406147npwtqwg.jpg", "aaaplatzhalter-eev4gvb1gk8384g.jpg"}
# The old 2019 image URLs redirect to the festival homepage (checked 2026-11-02).
# Keep that archive's names/descriptions, with a usable image until photos return.
ARCHIVE_IMAGE_FALLBACK_YEARS = {2019}
REPO = Path(__file__).resolve().parents[2]


class PlainText(HTMLParser):
    """Strip markup while keeping word boundaries and decoding HTML entities."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.ignored = 0

    def handle_starttag(self, tag, attrs):
        if tag in {"script", "style"}:
            self.ignored += 1
        elif not self.ignored and tag in {"br", "p", "div", "li"}:
            self.parts.append(" ")

    def handle_endtag(self, tag):
        if tag in {"script", "style"}:
            self.ignored = max(0, self.ignored - 1)
        elif not self.ignored and tag in {"p", "div", "li"}:
            self.parts.append(" ")

    def handle_data(self, data):
        if not self.ignored:
            self.parts.append(data)


def plain_text(value):
    parser = PlainText()
    parser.feed(value or "")
    parser.close()
    return " ".join("".join(parser.parts).split())


def excerpt(value, limit=220):
    text = plain_text(value)
    if len(text) <= limit:
        return text
    shortened = text[: limit - 1].rsplit(" ", 1)[0]
    return (shortened or text[: limit - 1]).rstrip(" ,;:-") + "…"


def image_url(record, year, modern):
    if year in ARCHIVE_IMAGE_FALLBACK_YEARS:
        return FALLBACK_IMAGE
    candidates = (
        [record.get("img_full"), record.get("img_thumb")]
        if modern
        else [record.get("fullURL"), record.get("thumbURL")]
    )
    if not modern and record.get("image"):
        candidates.append(f"/data/{year}/images/full/{quote(record['image'], safe='')}")
    for candidate in candidates:
        if not candidate or candidate.rsplit("/", 1)[-1].lower() in PLACEHOLDERS:
            continue
        url = urlsplit(urljoin(FESTIVAL + "/", candidate))
        if url.scheme != "https" or url.netloc != "www.rudolstadt-festival.de":
            raise ValueError(f"Unexpected artist image URL: {candidate!r}")
        if not url.path.startswith(("/assets/images/", f"/data/{year}/images/")):
            raise ValueError(f"Unexpected artist image path: {candidate!r}")
        # Encode Unicode and spaces, preserving already encoded source paths.
        return urlunsplit(url._replace(path=quote(url.path, safe="/%:@")))
    return FALLBACK_IMAGE


@dataclass(frozen=True)
class Artist:
    year: int
    id: int
    name: str
    description: str
    image: str

    @property
    def url(self):
        return f"{SITE}/rudolstadt/{self.year}/artists/{self.id}"


def load_artists(resources):
    sources = {}
    for path in sorted(resources.glob("*_archive.json")):
        year = int(path.name.split("_", 1)[0])
        sources[year] = (path, False)
    # Live-format snapshots take precedence when the same year is archived.
    for path in sorted(resources.glob("*_rudolstadt_data.json")):
        year = int(path.name.split("_", 1)[0])
        sources[year] = (path, True)
    if not sources:
        raise ValueError("No bundled Rudolstadt festival data found")
    artists = []
    for year, (path, modern) in sorted(sources.items()):
        root = json.loads(path.read_text(encoding="utf-8"))
        if not modern and (root.get("schemaVersion") != 1 or root.get("year") != year):
            raise ValueError(f"Unsupported archive schema/year: {path}")
        records = root["artists"]
        if not isinstance(records, list) or not records:
            raise ValueError(f"No artist records: {path}")
        ids = set()
        for record in records:
            artist_id = record["id"]
            if type(artist_id) is not int or artist_id <= 0 or artist_id in ids:
                raise ValueError(f"Invalid/duplicate artist ID in {path}: {artist_id!r}")
            ids.add(artist_id)
            name = " ".join(unescape(record.get("name") or "").split())
            if not name or record.get("hide_artist" if modern else "hidden", False):
                continue
            description = excerpt(
                record.get("description_de" if modern else "de")
                or record.get("description_en" if modern else "en")
            )
            artists.append(Artist(
                year, artist_id, name,
                description or f"{name} beim Rudolstadt-Festival {year}. In der App entdecken.",
                image_url(record, year, modern),
            ))
    if not artists:
        raise ValueError("No public artists found")
    return sorted(artists, key=lambda artist: (artist.year, artist.id))


def render(template, artist):
    title = f"{artist.name} · Rudolstadt-Festival {artist.year}"
    image_alt = "Rudolstadt-App-Icon" if artist.image == FALLBACK_IMAGE else f"Künstlerfoto: {artist.name}"
    metadata = {
        "og:type": "website",
        "og:locale": "de_DE",
        "og:site_name": f"Rudolstadt-Festival {artist.year} · Inoffizielle App",
        "og:title": title,
        "og:description": artist.description,
        "og:url": artist.url,
        "og:image": artist.image,
        "og:image:alt": image_alt,
    }
    lines = [f'    <link rel="canonical" href="{escape(artist.url, quote=True)}">']
    lines.extend(
        f'    <meta property="{key}" content="{escape(value, quote=True)}">'
        for key, value in metadata.items()
    )
    twitter = {
        "twitter:card": "summary" if artist.image == FALLBACK_IMAGE else "summary_large_image",
        "twitter:title": title,
        "twitter:description": artist.description,
        "twitter:image": artist.image,
        "twitter:image:alt": image_alt,
    }
    lines.extend(
        f'    <meta name="{key}" content="{escape(value, quote=True)}">'
        for key, value in twitter.items()
    )
    page, titles = re.subn(r"<title>[^<]*</title>", lambda _: f"<title>{escape(title)}</title>", template)
    page, descriptions = re.subn(
        r'<meta name="description" content="[^"]*">',
        lambda _: f'<meta name="description" content="{escape(artist.description, quote=True)}">',
        page,
    )
    if titles != 1 or descriptions != 1 or page.count("</head>") != 1:
        raise ValueError("Download template must contain one title, description and head")
    return page.replace("</head>", "\n".join(lines) + "\n</head>")


def build(repo=REPO):
    source = repo / "website"
    output = repo / "artifacts/website"
    if output.is_symlink():
        raise ValueError("Refusing to replace a symlink at artifacts/website")
    artists = load_artists(repo / "shared/src/commonMain/resources/FestivalBackup")
    template = (source / "rudolstadt/index.html").read_text(encoding="utf-8")
    pages = [(artist, render(template, artist)) for artist in artists]
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="website-build-", dir=output.parent) as temporary:
        staging = Path(temporary) / "website"
        shutil.copytree(source, staging, ignore=shutil.ignore_patterns("README.md", ".assetsignore"))
        # Unknown/hidden artist URLs still show the download UI, with HTTP 404.
        (staging / "rudolstadt/404.html").write_text(template, encoding="utf-8")
        for artist, page in pages:
            target = staging / f"rudolstadt/{artist.year}/artists/{artist.id}.html"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(page, encoding="utf-8")
        if output.exists():
            shutil.rmtree(output)
        staging.rename(output)
    print(f"Built {len(artists)} artist previews ({', '.join(str(y) for y in sorted({a.year for a in artists}))}) → {output}")
    return artists


if __name__ == "__main__":
    build()
