"""Check saved Sketch bindings against API fixtures and build channel images."""
import hashlib
import html
import json
import math
from pathlib import Path
import struct
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
MAGICK = "/opt/homebrew/bin/magick"


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(*args, **kwargs):
    return subprocess.run([MAGICK, *map(str, args)], check=True, **kwargs)


def pages(path):
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        return {n: json.loads(z.read(n)) for n in z.namelist()
                if n.startswith("pages/") and n.endswith(".json")}


def flatten(page):
    out = {}

    def walk(layer):
        out[layer["do_objectID"]] = layer
        for v in layer.get("frame", {}).values():
            if isinstance(v, (float, int)):
                assert math.isfinite(v)
        for child in layer.get("layers", []):
            walk(child)

    walk(page)
    return out


fixture = read(HERE / "api-fixture.json")
assert sha(ROOT / fixture["sourcePath"]) == fixture["sourceSha256"]
api = read(ROOT / fixture["sourcePath"])
artists = {x["id"]: x for x in api["artists"]}
events = {x["id"]: x for x in api["events"]}
stages = {x["id"]: x for x in api["stages"]}
before = pages(ROOT / "design/recovery/2026-11-04-before-schedule-api-correction/Rudolstadt.sketch")
after = pages(ROOT / "design/Rudolstadt.sketch")
assert before.keys() == after.keys()
changed_pages = []
for name in before:
    assert flatten(before[name]).keys() == flatten(after[name]).keys()
    if before[name] != after[name]:
        changed_pages.append(after[name]["name"])
assert set(changed_pages) <= {"Schedule", "Symbols"}
all_layers = {k: v for p in after.values() for k, v in flatten(p).items()}
old_layers = {k: v for p in before.values() for k, v in flatten(p).items()}
ref = "94CE2975-FDF5-4F05-BE1E-ADD65833BB57"
assert old_layers[ref] == all_layers[ref]
title_ids = {"D1CC78A8-54B6-4D06-B312-49AE570E2B45", "3CE3AD20-C443-4F8B-8F93-C4A7838871C3",
             "8E352CEE-7B6C-4FFC-9380-01004993C0A3", "EF65AC33-4245-49E9-854E-B6186CA623AF",
             "B5E87BF8-58F5-4AA3-A577-382729222044", "7BAE1203-E942-43F2-8733-9297C63064FE"}
time_ids = {"9A0E7B79-5E50-4F4F-AB70-4D1472866C3F", "9D7D441B-6D4B-404A-A875-B71BFF977779",
            "29BAD552-AA34-4463-BB5E-EBA8ACBC1697", "A555BD6B-EBC9-4976-B2AE-2653BF5A65B7",
            "B6538C9E-62BB-4824-8414-7BC61BBFD994"}


def derived(display, full):
    return full.startswith(display[:-1]) if display.endswith("…") else display == full


for row in fixture["rows"] + fixture["componentRows"]:
    layer = all_layers[row["layerId"]]
    saved = json.loads(next(v["scheduleAPI"] for v in layer["userInfo"].values()
                            if isinstance(v, dict) and "scheduleAPI" in v))
    event = events[saved["eventId"]]
    full = html.unescape(artists[event["artist"]]["name"])
    assert saved["artistId"] == event["artist"] and saved["stageId"] == event["stage"]
    assert saved["artistName"] == full and saved["time"] == event["time"]
    for o in layer.get("overrideValues", []):
        key = o["overrideName"]
        if not key.endswith("_stringValue"):
            continue
        text_id = key.split("_")[0]
        if text_id in title_ids:
            assert derived(o["value"], full), (row["layerId"], o["value"], full)
        if text_id in time_ids:
            assert o["value"] == event["time"]
    if row in fixture["rows"]:
        f = layer["frame"]
        minutes = int(event["time"][:2]) * 60 + int(event["time"][3:])
        android = row["platform"] == "android"
        assert f["x"] == 60 + 75 * (stages[event["stage"]]["map_number"] - 1)
        assert abs(f["y"] - ((221 if android else 192) +
                            (minutes - 600) * (1.2 if android else 1))) < .01
        assert f["height"] == old_layers[row["layerId"]]["frame"]["height"]

expanded = fixture["expanded"]
assert sha(ROOT / expanded["metadataSourcePath"]) == expanded["metadataSourceSha256"]
metadata = read(ROOT / expanded["metadataSourcePath"])["data"][expanded["artistName"]]["de"]
assert expanded["keywords"] == metadata["tags"] and expanded["summary"] == metadata["summary"]
assert events[171]["tags"] == [] and artists[213]["country"] == "AUT"
assert not all_layers["81F59EF2-EC48-43EA-904C-A4E22BA79ACA"]["isVisible"]

images = {}
for name in ("ios", "android", "ios-standard", "components"):
    paths = [HERE / f"{name}-{state}.png" for state in ("before", "after")]
    dims = [struct.unpack(">II", p.read_bytes()[16:24]) for p in paths]
    assert dims[0] == dims[1]
    gray = [run(p, "-colorspace", "Gray", "-depth", "8", "gray:-",
                stdout=subprocess.PIPE).stdout for p in paths]
    assert len(gray[0]) == len(gray[1]) == math.prod(dims[0])
    rgb = bytearray()
    for old, new in zip(*gray):
        value = min(255, abs(new - old) * 3)
        rgb.extend((value, 0, value) if new > old else (0, value, 0))
    w, h = dims[0]
    run("ppm:-", HERE / f"{name}-channels.png", input=f"P6\n{w} {h}\n255\n".encode() + rgb)
    images[name] = {"sizePx": dims[0], "beforeSha256": sha(paths[0]), "afterSha256": sha(paths[1])}
run(HERE / "ios-after.png", HERE / "android-after.png", "-background", "#f0f0f0",
    "+append", "-resize", "50%", HERE / "schedule-ios-android.png")
report = {"date": "2026-11-04", "checkedTimelineCards": 43, "checkedComponentExamples": 6,
          "dataSource": fixture["sourcePath"], "liveFetch": fixture["liveFetch"],
          "allPageAndLayerIDsPreserved": True, "referenceUnchanged": True,
          "changedPages": changed_pages, "timelinePositionsMatchAPIStartTimes": True,
          "titlesAreExactNamesOrDerivedPrefixes": True, "estimatedHeightsPreserved": True,
          "additionalMetadata": expanded["metadataSourcePath"], "images": images,
          "channels": "Gray(after)-Gray(before), gain 3; black equal, magenta lighter, green darker; no masking/alignment",
          "reopen": {"success": True, "documentId": "2D1524E4-82B8-424A-AFB4-2B8AA4AEB9EE"},
          "runtimeComparison": False}
(HERE / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: v for k, v in report.items() if k != "images"}, ensure_ascii=False))
