"""Extract the native map surface; exclude app chrome without inventing map data."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
source = Path(sys.argv[1])
reference = root / "ios-orte-reference@3x.png"
if source.resolve() != reference:
    shutil.copyfile(source, reference)
image = Image.open(reference).convert("RGBA")
assert image.size == (1206, 2622)
surface = image.copy()
mask = Image.new("L", image.size, 255)
draw = ImageDraw.Draw(mask)
draw.rectangle((0, 0, 1206, 347), fill=0)
for bounds, radius in [
    ((51, 382, 377, 475), 47),
    ((396, 382, 913, 475), 47),
    ((931, 382, 1230, 475), 47),
    ((1048, 2119, 1162, 2233), 57),
    ((60, 2371, 1146, 2562), 96),
]:
    draw.rounded_rectangle(bounds, radius=radius, fill=0)
for x in range(23, 542):
    for y in range(2301, 2352):
        red, green, blue, _ = image.getpixel((x, y))
        if max(red, green, blue) < 195 and max(red, green, blue) - min(red, green, blue) < 38:
            mask.putpixel((x, y), 0)
surface.putalpha(mask)
surface.save(root / "ios-orte-map-surface@3x.png")
image.crop((0, 0, 1206, 60)).save(root / "ios-orte-navigation-material.png")

manifest = {
    "createdDate": "2026-11-04",
    "source": "User-supplied screenshot in this chat; no new simulator run.",
    "reference": reference.name,
    "referenceSHA256": hashlib.sha256(reference.read_bytes()).hexdigest(),
    "pixelSize": [1206, 2622],
    "logicalSize": [402, 874],
    "scale": 3,
    "language": "German",
    "appearance": "Light",
    "deviceAndOS": "Not supplied; screenshot geometry matches 402 × 874 pt @3×.",
    "dynamicType": "Not supplied; typography follows visible screenshot and current code.",
    "state": "Geographic overview, all three admission filters enabled, no selected place or sheet.",
    "nativeMapSurface": {
        "file": "ios-orte-map-surface@3x.png",
        "rectPoints": [0, 116, 402, 758],
        "content": "Unmodified native cartography and MapKit annotations, including numbered and parking pins.",
        "excluded": "Navigation, filter capsules, recenter control, map attribution, tab bar.",
        "cutouts": "Transparent extraction masks; no generated or inferred cartography.",
    },
    "navigationMaterial": "Text-free top 60 px of source; stretched as an approximate material backdrop.",
    "editableUI": ["Navigation title", "Category filter labels and dots", "List and recenter vector icons", "Map attribution", "Shared native status and locations tab components"],
    "limitations": "Map labels and native annotations are part of the reference bitmap. Glass material is approximated. No newly captured runtime reference.",
}
(root / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"ok": True, "files": [p.name for p in root.iterdir()]}))
