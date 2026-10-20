"""Render the three editable bird variants and their comparison with librsvg."""

from copy import deepcopy
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent
NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)
VARIANTS = [
    ("01-der-musikant", "Der Musikant", "Kompakt · großes Akkordeon · offener Blick"),
    ("02-der-taenzer", "Der Tänzer", "Langer Balg · schräger Takt · Tanzschritt"),
    ("03-der-blechvogel", "Der Blechvogel", "Großes Horn · geschlossene Augen · Schwung"),
]


def element(parent, tag, attributes=None, text=None):
    node = ET.SubElement(parent, f"{{{NS}}}{tag}", attributes or {})
    node.text = text
    return node


def comparison():
    root = ET.Element(f"{{{NS}}}svg", {
        "width": "1560", "height": "1050", "viewBox": "0 0 1560 1050",
        "role": "img", "aria-labelledby": "title description",
    })
    element(root, "title", {"id": "title"}, "Drei Festivalvögel — SVG-Varianten")
    element(root, "desc", {"id": "description"},
            "Drei Vogel-Entwürfe mit gleichem Farbsystem bei 416, 96, 60 und "
            "40 Pixeln. Die runden Ecken dienen der Vorschau, sie simulieren "
            "keine native iOS-Icon-Maske.")
    defs = element(root, "defs")
    mask = element(defs, "clipPath", {"id": "rounded-preview"})
    element(mask, "rect", {"width": "1024", "height": "1024", "rx": "230"})
    for index, (stem, _, _) in enumerate(VARIANTS):
        group = element(defs, "g", {"id": f"variant-{index}"})
        source = ET.parse(ROOT / f"{stem}.svg").getroot()
        for child in source:
            if child.tag != f"{{{NS}}}g":
                continue
            copy = deepcopy(child)
            for node in copy.iter():
                if "id" in node.attrib:
                    node.set("id", f"v{index}-{node.attrib['id']}")
            group.append(copy)
    element(root, "path", {"fill": "#F1EEE7", "d": "M0 0H1560V1050H0Z"})

    def label(x, y, text, size=20, color="#776D7C", weight="400"):
        element(root, "text", {
            "x": str(x), "y": str(y), "fill": color,
            "font-family": "Helvetica Neue, Helvetica, Arial, sans-serif",
            "font-size": str(size), "font-weight": weight,
        }, text)

    def icon(index, x, y, size):
        position = element(root, "g", {
            "transform": f"translate({x} {y}) scale({size / 1024})",
        })
        clipped = element(position, "g", {"clip-path": "url(#rounded-preview)"})
        element(clipped, "use", {"href": f"#variant-{index}"})

    label(80, 69, "RUDOLSTADT / FESTIVALVOGEL", 18, weight="500")
    label(76, 135, "Drei Vögel. Ein Festival.", 55, "#30243C", "500")
    label(80, 177, "Violett, Creme und Kupferorange · drei eigenständige SVG-Varianten", 22)
    element(root, "path", {"stroke": "#D8D1D5", "d": "M80 202H1480"})
    for index, (_, title, subtitle) in enumerate(VARIANTS):
        x = 80 + index * 492
        label(x, 232, f"0{index + 1}", 17, weight="500")
        icon(index, x, 252, 416)
        label(x, 722, title, 32, "#30243C", "500")
        label(x, 760, subtitle, 18)
        for offset, size in ((0, 96), (156, 60), (280, 40)):
            icon(index, x + offset, 820 + (96 - size) / 2, size)
            label(x + offset, 949, f"{size} px", 17)
    element(root, "path", {"stroke": "#D8D1D5", "d": "M80 985H1480"})
    label(80, 1020, "1024 × 1024 · reine Vektorformen · Rundungen nur in dieser Vorschau", 18)
    ET.indent(root, space="  ")
    ET.ElementTree(root).write(ROOT / "vergleich.svg", encoding="unicode")


if __name__ == "__main__":
    comparison()
    for stem in [v[0] for v in VARIANTS] + ["vergleich"]:
        subprocess.run([
            "rsvg-convert", str(ROOT / f"{stem}.svg"),
            "-o", str(ROOT / f"{stem}.png"),
        ], check=True)
        print(f"Rendered {stem}.svg")
