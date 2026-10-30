"""Export the approved vector master as Android resources and a Play Store PNG.

Run with Python 3, librsvg and ImageMagick. The master uses a 108dp canvas;
the Store image shows its central 72dp viewport without a baked-in mask.
"""
from copy import deepcopy
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
RES = ROOT.parent / "src/main/res"
ANDROID = "http://schemas.android.com/apk/res/android"
SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("android", ANDROID)
ET.register_namespace("", SVG)


def attr(name):
    return f"{{{ANDROID}}}{name}"


def write_xml(element, path):
    ET.indent(element, space="    ")
    ET.ElementTree(element).write(path, encoding="utf-8", xml_declaration=True)


master = ET.parse(ROOT / "launcher-icon.svg").getroot()
paths = master.findall(f"{{{SVG}}}path")
if len(paths) != 2 or master.get("viewBox") != "0 0 108 108":
    raise ValueError("Expected the two approved foreground paths on a 108dp canvas")

for name, monochrome in [("foreground", False), ("monochrome", True)]:
    vector = ET.Element("vector", {
        attr("width"): "108dp", attr("height"): "108dp",
        attr("viewportWidth"): "108", attr("viewportHeight"): "108",
    })
    for path in paths:
        ET.SubElement(vector, "path", {
            attr("fillColor"): "#FFFFFFFF" if monochrome else path.attrib["fill"],
            attr("fillType"): "nonZero",
            attr("pathData"): path.attrib["d"],
        })
    write_xml(vector, RES / f"drawable/ic_launcher_{name}.xml")

background = ET.Element("shape", {attr("shape"): "rectangle"})
ET.SubElement(background, "solid", {attr("color"): "@color/launcher_background"})
write_xml(background, RES / "drawable/ic_launcher_background.xml")

store = deepcopy(master)
store.attrib.update(width="512", height="512", viewBox="18 18 72 72")
with tempfile.TemporaryDirectory(prefix="rudolstadt-icon-") as directory:
    svg = Path(directory) / "store.svg"
    png = Path(directory) / "store.png"
    write_xml(store, svg)
    subprocess.run(["rsvg-convert", str(svg), "-o", str(png)], check=True)
    subprocess.run([
        "magick", str(png), "-colorspace", "sRGB", "-define", "png:color-type=6",
        f"PNG32:{ROOT / 'play-store-icon.png'}",
    ], check=True)
print("Exported adaptive foreground, monochrome mask, background and 512px Store icon.")
