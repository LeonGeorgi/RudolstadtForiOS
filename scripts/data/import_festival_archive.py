#!/usr/bin/env python3
"""Normalize official .dat exports or APK JSON assets into a bundled snapshot."""

import argparse
import datetime
import hashlib
import json
import pathlib
import re


def records(directory, name, field_count):
    text = (directory / f"{name}.dat").read_text(encoding="utf-8")
    # Descriptions can span lines; only a numeric ID starts a new record.
    rows = [row.rstrip("\r\n").split("~") for row in
            re.split(r"(?m)(?=^\d+~)", text) if row.strip()]
    if not rows or any(len(row) != field_count for row in rows):
        raise ValueError(f"Invalid {name} export")
    ids = [int(row[0]) for row in rows]
    if len(set(ids)) != len(ids) or any(value <= 0 for value in ids):
        raise ValueError(f"Invalid or duplicate {name} IDs")
    return rows


def legacy_records(directory):
    areas = [dict(id=int(r[0]), de=r[1], en=r[2]) for r in records(directory, "areas", 3)]
    tags = [dict(id=int(r[0]), de=r[1], en=r[2]) for r in records(directory, "tags", 3)]
    artists = [dict(id=int(r[0]), type=int(r[1]), number=int(r[2]), name=r[3],
                    countries=r[4], website=r[5], facebook=r[6], youtube=r[7],
                    image=r[8], de=r[9], en=r[10])
               for r in records(directory, "artists", 11)]
    stages = [dict(id=int(r[0]), de=r[1], en=r[2], descriptionDE=r[3],
                   descriptionEN=r[4], number=int(r[5]) if r[5] else None,
                   latitude=float(r[6]) if r[6] else None,
                   longitude=float(r[7]) if r[7] else None,
                   area=int(r[8]), type=int(r[9]) if r[9] else None)
              for r in records(directory, "stages", 10)]
    events = [dict(id=int(r[0]), day=int(r[1]), time=r[2], stage=int(r[3]),
                   artist=int(r[4]), tags=[int(t) for t in r[5].split(",") if t])
              for r in records(directory, "events", 6)]
    return dict(artists=artists, areas=areas, stages=stages, events=events, tags=tags)


def modern_records(directory, year):
    def read(name):
        return json.loads((directory / f"{name}.json").read_text(encoding="utf-8"))

    def localized(record):
        return dict(id=record["id"], de=record["title"], en=record["title_en"])

    tags = [localized(r) for r in read("tags")]
    areas = [localized(r) for r in read("areas")]
    events = []
    for r in read("events"):
        start = datetime.datetime.strptime(r["start"]["date"], "%Y-%m-%d %H:%M:%S.%f")
        if (start.year != year or start.month != 7
                or start.strftime("%d.%m.%Y") != r["day"] or start.strftime("%H:%M") != r["time"]
                or r["start"]["timezone"] != "Europe/Berlin"):
            raise ValueError(f"Unexpected event date: {r['id']}")
        events.append(dict(id=r["id"], day=start.day, time=r["time"],
                           stage=r["stage"], artist=r["artist"], tags=r["tags"]))
    street_tag_ids = {r["id"] for r in tags if r["de"] == "Straßenmusik"}
    street_artist_ids = {r["artist"] for r in events if street_tag_ids.intersection(r["tags"])}
    artists = []
    for r in read("artists"):
        artist_type = {"concert": 3 if r["id"] in street_artist_ids else 1,
                       "dancing": 2, "festival-plus": 4}[r["category"]]
        artists.append(dict(id=r["id"], type=artist_type, number=0, name=r["name"],
                            countries=r["country"] or "", website=r["website"] or "",
                            facebook=r["facebook"] or "", youtube=r["video"] or "",
                            instagram=r["instagram"], hidden=r["hide_artist"], image="",
                            thumbURL=r["img_thumb"], fullURL=r["img_full"],
                            de=r["description_de"], en=r["description_en"]))
    stages = [dict(id=r["id"], de=r["title"], en=r["title_en"],
                   descriptionDE=r["description"] or "", descriptionEN=r["description_en"] or "",
                   number=r["map_number"], latitude=r["lat"], longitude=r["lon"], area=r["area"],
                   type={"comboticket": 1, "cityticket": 2, "information": 3}[r["category"]])
              for r in read("stages")]
    return dict(artists=artists, areas=areas, stages=stages, events=events, tags=tags)


def snapshot(directory, year, source_url=None, source_version=None):
    extension = "json" if (directory / "artists.json").exists() else "dat"
    data = modern_records(directory, year) if extension == "json" else legacy_records(directory)
    artists, areas, stages, events, tags = (data[k] for k in ["artists", "areas", "stages", "events", "tags"])
    for name, values in data.items():
        ids = [r["id"] for r in values]
        if not ids or len(set(ids)) != len(ids) or any(value <= 0 for value in ids):
            raise ValueError(f"Invalid or duplicate {name} IDs")
    for event in events:
        datetime.datetime.strptime(f"{year}-07-{event['day']:02d} {event['time']}", "%Y-%m-%d %H:%M")
        for key, values in [("stage", stages), ("artist", artists)]:
            if event[key] not in {value["id"] for value in values}:
                raise ValueError(f"Missing {key} for event {event['id']}")
        if not set(event["tags"]) <= {tag["id"] for tag in tags}:
            raise ValueError(f"Missing tag for event {event['id']}")
    if any(stage["area"] not in {area["id"] for area in areas} for stage in stages):
        raise ValueError("Missing stage area")
    files = {name: directory / f"{name}.{extension}" for name in data}
    captured_at = datetime.datetime.fromtimestamp(max(p.stat().st_mtime for p in files.values()),
                                                 datetime.timezone.utc)
    return dict(schemaVersion=1, year=year, capturedAt=captured_at.isoformat(),
                sourceRelease=source_version,
                sources={name: dict(url=source_url or f"https://www.rudolstadt-festival.de/data/{year}/{p.name}",
                                    file=p.name, sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                         for name, p in files.items()}, **data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--year", type=int, required=True)
    parser.add_argument("--source-url", help="APK release page when importing bundled assets")
    parser.add_argument("--source-version", help="APK release version")
    args = parser.parse_args()
    data = snapshot(args.directory, args.year, args.source_url, args.source_version)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Imported {len(data['artists'])} artists and {len(data['events'])} events for {args.year}")
