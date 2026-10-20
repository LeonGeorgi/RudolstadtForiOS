"""Render both bird studies and their comparison using local librsvg."""
from copy import deepcopy
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)


def element(parent, tag, **attributes):
    return ET.SubElement(parent, f"{{{NS}}}{tag}", attributes)


board = ET.Element(f"{{{NS}}}svg", {
    "width": "1200", "height": "890", "viewBox": "0 0 1200 890",
    "role": "img", "aria-labelledby": "board-title",
})
element(board, "title", id="board-title").text = "Akkordeonvogel: vorher und zweite Überarbeitung"
defs = element(board, "defs")
mask = element(defs, "clipPath", id="icon-mask")
element(mask, "rect", width="1024", height="1024", rx="230")
element(board, "rect", width="1200", height="890", fill="#F1EEE7")


def label(x, y, value, size=18):
    node = element(board, "text", x=str(x), y=str(y), fill="#492B55",
                   **{"font-family": "Helvetica, Arial, sans-serif", "font-size": str(size)})
    node.text = value


label(64, 56, "AKKORDEONVOGEL / RUNDE 2", 20)
for index, (name, caption) in enumerate([
    ("04-akkordeonvogel", "Vorher"),
    ("05-akkordeonvogel", "Überarbeitet"),
]):
    source = ET.parse(ROOT / f"{name}.svg").getroot()
    assert source.get("viewBox") == "0 0 1024 1024"
    ids = [node.get("id") for node in source.iter() if node.get("id")]
    assert len(ids) == len(set(ids)), "Duplicate source IDs"
    assert not any(node.tag.rsplit("}", 1)[-1] in ("image", "script", "foreignObject")
                   for node in source.iter()), "Expected standalone vector artwork"
    symbol = element(defs, "g", id=f"bird-{index}")
    for group in source.findall(f"{{{NS}}}g"):
        clone = deepcopy(group)
        for node in clone.iter():
            if "id" in node.attrib:
                node.set("id", f"v{index}-{node.get('id')}")
        symbol.append(clone)
    x = 64 + index * 576
    label(x, 111, caption, 26)
    for offset, y, size in [(0, 140, 496), (0, 685, 96), (160, 717, 64), (288, 741, 40)]:
        frame = element(board, "g", transform=f"translate({x + offset} {y}) scale({size / 1024})")
        clip = element(frame, "g", **{"clip-path": "url(#icon-mask)"})
        element(clip, "use", href=f"#bird-{index}")
        if size < 496:
            label(x + offset, 815, f"{size} px", 16)
    subprocess.run(["rsvg-convert", "-o", str(ROOT / f"{name}.png"),
                    str(ROOT / f"{name}.svg")], check=True)

destination = ROOT / "runde-2-vergleich.svg"
ET.ElementTree(board).write(destination, encoding="unicode")
subprocess.run(["rsvg-convert", "-o", str(destination.with_suffix(".png")),
                str(destination)], check=True)
print("Validated and rendered both studies and comparison.")
