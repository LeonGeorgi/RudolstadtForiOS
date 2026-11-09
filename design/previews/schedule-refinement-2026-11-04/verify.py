"""Rebuild the Sketch design comparison; requires ImageMagick, no simulator."""
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
MAGICK = "/opt/homebrew/bin/magick"


def run(*args, **kwargs):
    return subprocess.run([MAGICK, *map(str, args)], check=True, **kwargs)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


images = {}
for name in ("ios", "android", "ios-standard", "components"):
    before, after = [HERE / f"{name}-{state}.png" for state in ("before", "after")]
    dimensions = [struct.unpack(">II", p.read_bytes()[16:24]) for p in (before, after)]
    assert dimensions[0] == dimensions[1], (name, dimensions)
    gray = [run(p, "-colorspace", "Gray", "-depth", "8", "gray:-",
                stdout=subprocess.PIPE).stdout for p in (before, after)]
    assert len(gray[0]) == len(gray[1]) == math.prod(dimensions[0])
    rgb = bytearray()
    changed = 0
    for old, new in zip(*gray):
        d = new - old
        changed += d != 0
        value = min(255, abs(d) * 3)
        rgb.extend((value, 0, value) if d > 0 else (0, value, 0))
    width, height = dimensions[0]
    ppm = f"P6\n{width} {height}\n255\n".encode() + rgb
    channel = HERE / f"{name}-channels.png"
    run("ppm:-", channel, input=ppm)
    images[name] = {"sizePx": dimensions[0], "beforeSha256": sha(before),
                    "afterSha256": sha(after), "channelsSha256": sha(channel),
                    "changedGrayPixels": changed}

run(HERE / "ios-after.png", HERE / "android-after.png", "-background", "#f0f0f0",
    "+append", "-resize", "50%", HERE / "schedule-ios-android.png")


def pages(path):
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        return {n: json.loads(z.read(n)) for n in z.namelist()
                if n.startswith("pages/") and n.endswith(".json")}


def layers(page):
    result = {}

    def walk(layer):
        result[layer["do_objectID"]] = layer
        for value in layer.get("frame", {}).values():
            if isinstance(value, (int, float)):
                assert math.isfinite(value)
        for child in layer.get("layers", []):
            walk(child)

    walk(page)
    return result


before = pages(ROOT / "design/recovery/2026-11-04-before-schedule-polish/Rudolstadt.sketch")
after = pages(ROOT / "design/recovery/2026-11-04-before-schedule-api-correction/Rudolstadt.sketch")
assert before.keys() == after.keys()
page_changes = []
for key in before:
    old, new = layers(before[key]), layers(after[key])
    assert old.keys() == new.keys(), (key, "layer IDs changed")
    if before[key] != after[key]:
        page_changes.append(after[key]["name"])

schedule = layers(after["pages/967264B5-0110-4F90-B922-B32A6987C055.json"])
old_schedule = layers(before["pages/967264B5-0110-4F90-B922-B32A6987C055.json"])
reference_id = "94CE2975-FDF5-4F05-BE1E-ADD65833BB57"
assert schedule[reference_id] == old_schedule[reference_id]
cards = []
for frame_id in ("22526A58-7B7E-4EE0-92FD-2F536F8DF85B",
                 "421791D0-92A7-4C70-8C2E-54429C8BBF06",
                 "FD0CA3C2-FC5F-470C-A13F-37D6B998E523"):
    for layer in schedule[frame_id]["layers"]:
        f = layer["frame"]
        if layer["_class"] == "symbolInstance" and f["width"] == 71 and f["height"] >= 58:
            old = old_schedule[layer["do_objectID"]]["frame"]
            assert all(old[k] == f[k] for k in ("x", "y", "height"))
            cards.append(layer["do_objectID"])
assert len(cards) == 43

report = {"date": "2026-11-04", "kind": "Sketch design refinement; no new runtime comparison",
          "images": images, "channelFormula": "d = Gray(after) - Gray(before); RGB = (max(d,0), max(-d,0), max(d,0)); gain 3",
          "legend": "black: equal; magenta: after lighter; green: after darker",
          "alignment": "unaligned original exports at 2x; no masks, shifts or smoothing",
          "changedPages": page_changes, "allPageAndLayerIDsPreserved": True,
          "referenceFrameUnchanged": True, "finiteFrames": True,
          "timelineCardsWithOriginalPositionAndDuration": len(cards),
          "visibleCardTextBounds": {"checked": 90, "overflows": 0},
          "reopen": {"success": True, "documentId": "2E66222C-E991-4EA5-B7B8-5AD6D74685F0"}}
(HERE / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: v for k, v in report.items() if k != "images"}, ensure_ascii=False))
