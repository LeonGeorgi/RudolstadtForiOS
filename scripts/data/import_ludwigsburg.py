#!/usr/bin/env python3
"""Build the isolated Ludwigsburg snapshot from the previously downloaded sources.

Usage: python3 scripts/data/import_ludwigsburg.py SOURCE_DIRECTORY OUTPUT_JSON
No network requests; only regular slots with valid published start/end times.
"""

import argparse
import copy
import hashlib
import html
import io
import json
import re
import struct
import subprocess
import tempfile
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from zoneinfo import ZoneInfo


class ArtistPage(HTMLParser):
    def __init__(self):
        super().__init__()
        self.image = ""
        self.paragraphs = []
        self.paragraph = None
        self.links = {}

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        classes = attrs.get("class", "").split()
        if tag == "img" and "urban-cover" in classes:
            self.image = attrs.get("src", "")
        if tag == "p":
            self.paragraph = []
        if tag == "a":
            for kind in ["facebook", "instagram", "youtube"]:
                if f"urban-social-link-{kind}" in classes:
                    self.links[kind] = attrs.get("href")

    def handle_data(self, data):
        if self.paragraph is not None:
            self.paragraph.append(data)

    def handle_endtag(self, tag):
        if tag == "p" and self.paragraph is not None:
            text = " ".join("".join(self.paragraph).split())
            if text:
                self.paragraphs.append(text)
            self.paragraph = None


COUNTRIES = {
    "Ukraine": "UKR", "Dänemark": "DNK", "Dänmark": "DNK", "Italien": "ITA",
    "Deutschland": "DEU", "Argentinien": "ARG", "Schweden": "SWE", "USA": "USA",
    "England": "GBR", "Niederlande": "NLD", "Spanien": "ESP", "Österreich": "AUT",
    "Polen": "POL", "Kuba": "CUB", "Frankreich": "FRA",
}


def prepare_site_plan(site_plan, source_pdf):
    """Crop in original PDF points (top-left origin), preserving vector overlays.

    Requires pypdf for curated crops. Source locations always stay relative to the
    original page; only the bundled snapshot receives transformed coordinates.
    """
    if hashlib.sha256(source_pdf).hexdigest() != site_plan["sourceSHA256"]:
        raise ValueError("The official site plan changed; review the curated locations before importing.")
    result = copy.deepcopy(site_plan)
    crop = result.pop("sourceCropBox", None)
    outline = result.pop("sourceClipPolygon", None)
    if crop is None:
        return result, source_pdf

    from pypdf import PdfReader, PdfWriter
    from pypdf.generic import DecodedStreamObject, NameObject, RectangleObject

    reader = PdfReader(io.BytesIO(source_pdf))
    if len(reader.pages) != 1:
        raise ValueError("The curated crop requires a single-page site plan.")
    page = reader.pages[0]
    bounds = page.mediabox
    width, height = float(bounds.width), float(bounds.height)
    x, y, crop_width, crop_height = (crop[key] for key in ("x", "y", "width", "height"))
    if page.rotation != 0 or not (0 <= x < x + crop_width <= width and 0 <= y < y + crop_height <= height):
        raise ValueError("Invalid source crop for the site plan.")
    if outline:
        points = [(float(bounds.left) + px, float(bounds.top) - py) for px, py in outline]
        path = f"{points[0][0]} {points[0][1]} m\n"
        path += "".join(f"{px} {py} l\n" for px, py in points[1:])
        stream = DecodedStreamObject()
        stream.set_data(b"q\n" + path.encode("ascii") + b"h W n\n"
                        + page.get_contents().get_data() + b"\nQ\n")
        page[NameObject("/Contents")] = stream
    cropped_bounds = RectangleObject((float(bounds.left) + x, float(bounds.top) - y - crop_height,
                                     float(bounds.left) + x + crop_width, float(bounds.top) - y))
    page.mediabox = cropped_bounds
    page.cropbox = cropped_bounds
    for location in result["locations"]:
        if point := location.get("point"):
            point["x"] = (point["x"] * width - x) / crop_width
            point["y"] = (point["y"] * height - y) / crop_height
            if not (0 <= point["x"] <= 1 and 0 <= point["y"] <= 1):
                raise ValueError(f"The crop excludes location {location['id']}.")
    writer = PdfWriter()
    writer.add_page(page)
    output = io.BytesIO()
    writer.write(output)
    cropped_pdf = output.getvalue()
    result["originalSourceSHA256"] = result["sourceSHA256"]
    result["sourceSHA256"] = hashlib.sha256(cropped_pdf).hexdigest()
    return result, cropped_pdf


def prepare_map_background(site_plan_pdf):
    """Render only the embedded drawing, keeping the cropped plan's coordinates."""
    from pypdf import PdfReader, PdfWriter
    from pypdf.generic import ContentStream, NameObject

    reader = PdfReader(io.BytesIO(site_plan_pdf))
    page = reader.pages[0]
    source_content = page.get_contents()
    if source_content is None:
        raise ValueError("The site plan drawing changed; review the background extraction.")
    operations = source_content.operations
    images = [index for index, (_, operator) in enumerate(operations) if operator == b"Do"]
    if len(images) != 1 or images[0] == 0 or operations[images[0] - 1][1] != b"cm":
        raise ValueError("The site plan drawing changed; review the background extraction.")
    index = images[0]
    content = ContentStream(None, reader)
    content.operations = [([], b"q"), operations[index - 1], operations[index], ([], b"Q")]
    page[NameObject("/Contents")] = content
    writer = PdfWriter()
    writer.add_page(page)
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory)
        writer.write(path / "background.pdf")
        subprocess.run(["pdftoppm", "-scale-to", "2200", "-singlefile", "-png",
                        str(path / "background.pdf"), str(path / "background")], check=True, capture_output=True)
        return (path / "background.png").read_bytes()


def build_snapshot(source):
    program_path = source / "program.json"
    program = json.loads(program_path.read_text())
    assert program["year"] == 2026
    events = []
    omitted = 0
    for record in program["events"]:
        start = datetime.fromisoformat(f"{record['date']}T{record['start']}")
        end = datetime.fromisoformat(f"{record['date']}T{record['end']}")
        if not record["artistNumber"] or end <= start or record.get("sourceIssue"):
            omitted += 1
            continue
        events.append((record, start, end))

    active_urls = {record["artistURL"] for record, _, _ in events}
    artists = []
    for record in program["artists"]:
        if record["url"] not in active_urls:
            continue
        content = (source / record["file"]).read_text()
        # Stop before the timetable and related artists so their metadata cannot leak in.
        header = content[content.index("<h1"):]
        intro = header.split('Spielzeiten</h1>', 1)[0]
        page = ArtistPage()
        page.feed(intro)
        number = int(re.search(r"Bandnummer:\s*(\d+)", intro)[1])
        country_names = list(dict.fromkeys(
            re.findall(r"Land:\s*-?\s*([^,<]+)", intro)
        ))
        country_names = [html.unescape(name).strip() for name in country_names]
        artists.append({
            "id": number, "name": record["headings"][0], "sourceURL": record["url"],
            "countries": ", ".join(country_names),
            "countryCodes": list(dict.fromkeys(COUNTRIES[name] for name in country_names)),
            "descriptionDE": "\n\n".join(page.paragraphs), "imageURL": page.image,
            **page.links,
        })

    stage_names = {record["stageURL"]: record["stage"].split(" — ")[0] for record, _, _ in events}
    stages = [{"id": i + 1, "name": name, "sourceURL": url}
              for i, (url, name) in enumerate(sorted(stage_names.items()))]
    stage_ids = {stage["sourceURL"]: stage["id"] for stage in stages}
    converted = []
    for record, start, end in events:
        identity = "|".join([record["date"], record["start"], record["stageURL"], record["artistURL"]])
        converted.append({
            "id": int(hashlib.sha256(identity.encode()).hexdigest()[:12], 16),
            "start": start.isoformat(timespec="minutes"),
            "durationMinutes": int((end - start).total_seconds() / 60),
            "artist": int(record["artistNumber"]), "stage": stage_ids[record["stageURL"]],
        })
    assert len({artist["id"] for artist in artists}) == len(artists)
    assert len({event["id"] for event in converted}) == len(converted)
    assert {event["artist"] for event in converted} == {artist["id"] for artist in artists}
    site_plan = json.loads(Path(__file__).with_name("ludwigsburg_2026_site_plan.json").read_text())
    return {
        "schemaVersion": 1, "festivalID": "ludwigsburg-2026", "year": 2026,
        "timeZone": ZoneInfo("Europe/Berlin").key,
        "sourceURL": "https://strassenmusikfestival.de/spielzeiten/",
        "retrievedAt": program["retrievedAt"],
        "sourceSHA256": hashlib.sha256(program_path.read_bytes()).hexdigest(),
        "omittedRecordCount": omitted,
        "artists": sorted(artists, key=lambda artist: artist["id"]),
        "stages": stages, "events": converted,
        "sitePlan": site_plan,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--map-output-directory", type=Path,
                        help="Directory for native PDF/PNG resources (defaults to the JSON directory)")
    args = parser.parse_args()
    snapshot = build_snapshot(args.source)
    snapshot["sitePlan"], pdf = prepare_site_plan(snapshot["sitePlan"], (args.source / "SMF2026_Lageplan.pdf").read_bytes())
    background = prepare_map_background(pdf)
    width, height = struct.unpack(">II", background[16:24])
    background_name = snapshot["sitePlan"]["resourceName"] + "_background"
    snapshot["sitePlan"]["background"] = {
        "resourceName": background_name, "width": width, "height": height,
        "sha256": hashlib.sha256(background).hexdigest(),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    map_directory = args.map_output_directory or args.output.parent
    map_directory.mkdir(parents=True, exist_ok=True)
    (map_directory / (background_name + ".png")).write_bytes(background)
    (map_directory / (snapshot["sitePlan"]["resourceName"] + ".pdf")).write_bytes(pdf)
    args.output.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
