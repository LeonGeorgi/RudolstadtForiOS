"""Native concept artwork: original lettering printed on three festival objects."""

import copy
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "Creative"
SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)

stacked = ET.parse(ROOT / "Refined/07-original-pur.icon/Assets/Originalschriftzug.svg").getroot().find(f"{{{SVG}}}g")
horizontal = ET.parse(OUTPUT / "SourceAssets/festival-wordmark-horizontal.svg").getroot().find(f"{{{SVG}}}g")
assert stacked is not None and horizontal is not None


def lettering(source, scale, cx, cy, color):
    artwork = copy.deepcopy(source)
    for element in artwork.iter(f"{{{SVG}}}path"):
        element.set("fill", color)
    return (
        f'<g transform="translate({cx - scale * 512:.3f} {cy - scale * 512:.3f}) scale({scale})">'
        + ET.tostring(artwork, encoding="unicode")
        + "</g>"
    )


def rotated(artwork, angle):
    return f'<g transform="rotate({angle} 512 512)">{artwork}</g>'


def path(d, color):
    return f'<path fill="{color}" d="{d}"/>'


def group(name, artwork, glass=True, shadow=0.15):
    return {
        "name": name,
        "lighting": "combined",
        "specular": glass,
        "shadow": {"kind": "neutral", "opacity": shadow if glass else 0},
        "translucency": {"enabled": glass, "value": 0.18 if glass else 0},
        "layers": [{"name": name, "artwork": artwork, "glass": glass}],
    }


def save(slug, title, groups):
    assets = OUTPUT / f"{slug}.icon" / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    for index, item in enumerate(groups):
        for layer in item["layers"]:
            filename = f"{index + 1:02d}-Layer.svg"
            body = layer.pop("artwork")
            (assets / filename).write_text(
                f'<svg xmlns="{SVG}" width="1024" height="1024" viewBox="0 0 1024 1024">'
                f"<title>{title}: {item['name']}</title>{body}</svg>\n"
            )
            layer["image-name"] = filename
    document = {
        "fill": {"automatic-gradient": "srgb:0.35500,0.11800,0.37000,1.00000"},
        "groups": list(reversed(groups)),
        "supported-platforms": {"squares": "shared"},
    }
    (assets.parent / "icon.json").write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n")
    print(f"{slug}.icon: original lettering, native glass object, flat printed ink")


WHITE = "#FCFAFF"
INK = "#672865"
COPPER = "#CA6A38"

# A ticket has one coherent silhouette with genuine tear-off notches.
ticket = path(
    "M306 196 H718 Q748 196 748 226 V620 C710 620 710 676 748 676 V802 "
    "Q748 832 718 832 H306 Q276 832 276 802 V676 C314 676 314 620 276 620 V226 Q276 196 306 196 Z",
    WHITE,
)
stub = path("M276 716 H748 V802 Q748 832 718 832 H306 Q276 832 276 802 Z", COPPER)
save("10-festivalpass", "10 · Festivalpass", [
    group("01 Ticket", rotated(ticket, -7)),
    group("02 Abriss", rotated(stub, -7)),
    group("03 Originalschriftzug", rotated(lettering(stacked, 0.54, 512, 448, INK), -7), glass=False),
])

# The asymmetric flap and fold line describe a programme/map, not a generic card.
flap = path("M638 246 L826 292 Q840 296 840 312 V760 Q840 782 819 776 L638 728 Z", COPPER)
front = path("M242 256 L630 192 Q650 189 650 210 V744 L242 810 Q220 814 220 792 V280 Q220 260 242 256 Z", WHITE)
route = '<path d="M706 352 L785 430 L711 507 L785 605" fill="none" stroke="#FCFAFF" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
route += "".join(f'<circle cx="{x}" cy="{y}" r="12" fill="{WHITE}"/>' for x, y in [(706, 352), (785, 430), (711, 507), (785, 605)])
save("11-festivalplan", "11 · Festivalplan", [
    group("01 Gefaltete Karte", flap),
    group("02 Titelseite", front),
    group("03 Originalschriftzug", lettering(stacked, 0.56, 435, 503, INK), glass=False),
    group("04 Buehnenweg", route, glass=False),
])

# A real loop silhouette, with the festival's horizontal wordmark across its front.
back = path(
    "M222 428 C211 324 331 238 510 239 C704 239 813 328 812 438 L790 550 "
    "C786 442 671 369 510 369 C351 369 249 442 244 550 Z", "#A84B2D"
)
band = path("M222 428 C330 485 703 485 812 438 L790 634 C682 698 352 698 244 634 Z", COPPER)
save("12-festivalband", "12 · Festivalband", [
    group("01 Bandschlaufe", rotated(back, -9)),
    group("02 Vorderseite", rotated(band, -9)),
    group("03 Originalschriftzug", rotated(lettering(horizontal, 0.58, 517, 563, WHITE), -9), glass=False),
])
