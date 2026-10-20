"""Build the lettering study and render the three standalone SVG concepts."""

from copy import deepcopy
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent
SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)


def make_lettering():
    source = ROOT.parent / "Refined/08-ru-signet.icon/Assets/Originalschriftzug.svg"
    original = ET.parse(source).getroot()
    group = original.find(f"{{{SVG}}}g")
    path = group.find(f"{{{SVG}}}path")
    contours = re.findall(r"M[^M]*", path.attrib["d"])
    if len(contours) != 2:
        raise ValueError("Expected the two existing r and u contours")
    output = ET.Element(
        f"{{{SVG}}}svg",
        {"width": "1024", "height": "1024", "viewBox": "0 0 1024 1024",
         "role": "img", "aria-labelledby": "title description"},
    )
    ET.SubElement(output, f"{{{SVG}}}title", {"id": "title"}).text = (
        "ru im Takt — Rudolstadt Icon-Entwurf"
    )
    ET.SubElement(output, f"{{{SVG}}}desc", {"id": "description"}).text = (
        "Die vorhandenen r- und u-Konturen des Festival-Schriftzugs in Creme "
        "und Kupferorange, vergrößert auf tiefviolettem Grund."
    )
    background = ET.SubElement(output, f"{{{SVG}}}g", {"id": "background"})
    ET.SubElement(background, f"{{{SVG}}}path", {
        "fill": "#492B55", "d": "M0 0H1024V1024H0Z",
    })
    artwork = ET.SubElement(output, f"{{{SVG}}}g", {
        "id": "artwork", "transform": "translate(-118 -30) scale(1.23 1.05)",
    })
    lettering = ET.SubElement(artwork, f"{{{SVG}}}g", {
        "id": "original-lettering", "transform": group.attrib["transform"],
    })
    for name, color, contour in zip(
        ("letter-r", "letter-u"), ("#F5E7CE", "#EAA16A"), contours
    ):
        ET.SubElement(lettering, f"{{{SVG}}}path", {
            "id": name, "fill": color, "fill-rule": "evenodd", "d": contour,
        })
    ET.indent(output, space="  ")
    ET.ElementTree(output).write(ROOT / "02-ru-im-takt.svg", encoding="unicode")


def make_comparison():
    studies = [
        ("01-festivalvogel", "Festivalvogel", "Figur · Humor · Bewegung"),
        ("02-ru-im-takt", "ru im Takt", "Originalkonturen · Farbe · Rhythmus"),
        ("03-leuchtobjekt", "Laternenklang", "Papier · Licht · räumliche Gestaltung"),
    ]
    output = ET.Element(f"{{{SVG}}}svg", {
        "width": "1560", "height": "1050", "viewBox": "0 0 1560 1050",
        "role": "img", "aria-labelledby": "comparison-title comparison-desc",
    })
    ET.SubElement(output, f"{{{SVG}}}title", {"id": "comparison-title"}).text = (
        "Rudolstadt — drei Icon-Entwürfe"
    )
    ET.SubElement(output, f"{{{SVG}}}desc", {"id": "comparison-desc"}).text = (
        "Festivalvogel, ru im Takt und Laternenklang im direkten Vergleich "
        "sowie jeweils bei 96, 60 und 40 Pixeln. Die Rundungen sind eine "
        "illustrative Vorschau, kein Systemrendering."
    )
    defs = ET.SubElement(output, f"{{{SVG}}}defs")
    for index, (stem, _, _) in enumerate(studies):
        symbol = ET.SubElement(defs, f"{{{SVG}}}symbol", {
            "id": f"study-{index}", "viewBox": "0 0 1024 1024",
        })
        for child in ET.parse(ROOT / f"{stem}.svg").getroot():
            if child.tag != f"{{{SVG}}}g":
                continue
            copied = deepcopy(child)
            for element in copied.iter():
                if "id" in element.attrib:
                    element.set("id", f"s{index}-{element.attrib['id']}")
            symbol.append(copied)
    ET.SubElement(output, f"{{{SVG}}}path", {
        "fill": "#F1EEE7", "d": "M0 0H1560V1050H0Z",
    })

    def label(x, y, text, size=20, color="#776D7C", weight="400"):
        element = ET.SubElement(output, f"{{{SVG}}}text", {
            "x": str(x), "y": str(y), "fill": color,
            "font-family": "Helvetica Neue, Helvetica, Arial, sans-serif",
            "font-size": str(size), "font-weight": weight,
        })
        element.text = text

    def icon(index, x, y, size, suffix):
        clip_id = f"mask-{index}-{suffix}"
        clip = ET.SubElement(defs, f"{{{SVG}}}clipPath", {"id": clip_id})
        ET.SubElement(clip, f"{{{SVG}}}rect", {
            "x": str(x), "y": str(y), "width": str(size), "height": str(size),
            "rx": str(size * .225),
        })
        ET.SubElement(output, f"{{{SVG}}}use", {
            "href": f"#study-{index}", "x": str(x), "y": str(y),
            "width": str(size), "height": str(size),
            "clip-path": f"url(#{clip_id})",
        })

    label(80, 69, "RUDOLSTADT / IDENTITY STUDIES", 18, weight="500")
    label(76, 135, "Drei Zeichen fürs Festival.", 55, "#30243C", "500")
    label(80, 177, "Violett, Creme und Kupferorange · frei editierbare SVG-Entwürfe", 22)
    ET.SubElement(output, f"{{{SVG}}}path", {
        "stroke": "#D8D1D5", "d": "M80 202H1480",
    })
    for index, (_, title, subtitle) in enumerate(studies):
        x = 80 + index * 492
        label(x, 232, f"0{index + 1}", 17, weight="500")
        icon(index, x, 252, 416, "large")
        label(x, 722, title, 32, "#30243C", "500")
        label(x, 760, subtitle, 20)
        for offset, size in ((0, 96), (156, 60), (280, 40)):
            icon(index, x + offset, 820 + (96 - size) / 2, size, str(size))
            label(x + offset, 949, f"{size} px", 17)
    ET.SubElement(output, f"{{{SVG}}}path", {
        "stroke": "#D8D1D5", "d": "M80 985H1480",
    })
    label(80, 1020, "1024 × 1024 · flächige Vektorformen · Rundungen nur in dieser Vorschau", 18)
    ET.indent(output, space="  ")
    ET.ElementTree(output).write(ROOT / "vergleich.svg", encoding="unicode")


if __name__ == "__main__":
    make_lettering()
    make_comparison()
    for stem in ("01-festivalvogel", "02-ru-im-takt", "03-leuchtobjekt", "vergleich"):
        subprocess.run([
            "rsvg-convert", str(ROOT / f"{stem}.svg"),
            "-o", str(ROOT / f"{stem}.png"),
        ], check=True)
        print(f"Rendered {stem}.svg")
