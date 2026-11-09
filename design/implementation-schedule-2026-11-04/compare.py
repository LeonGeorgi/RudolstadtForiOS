"""Rebuild native/Sketch comparisons without registration or resampling.

Requires ImageMagick (`magick`). Run from any working directory.
Only the iOS system bar (186 source pixels) is masked in channel images.
All differences remain visible in the RGB images. Gain: 3.
"""

import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAGICK = shutil.which("magick") or "/opt/homebrew/bin/magick"


def run(*args, data=None):
    return subprocess.run(
        [MAGICK, *map(str, args)], input=data, check=True, capture_output=True
    ).stdout


def dimensions(path):
    return tuple(map(int, run("identify", "-format", "%w %h", path).split()))


def rgb(path):
    return run(path, "-alpha", "off", "-depth", "8", "rgb:-")


def gray(pixels):
    return bytes(
        (299 * pixels[i] + 587 * pixels[i + 1] + 114 * pixels[i + 2] + 500) // 1000
        for i in range(0, len(pixels), 3)
    )


def save(pixels, size, name):
    run("-size", f"{size[0]}x{size[1]}", "-depth", "8", "rgb:-", ROOT / name, data=pixels)


manifest = []
for platform, native, mask_top in [
    ("ios", ROOT / "ios-standard.png", 186),
    ("android", ROOT / "android-final/standard.png", 0),
]:
    sketch = ROOT / f"{platform}-sketch.png"
    size = dimensions(sketch)
    assert size == dimensions(native), "Sources must have identical dimensions"
    a, b = rgb(sketch), rgb(native)
    ga, gb = gray(a), gray(b)
    channels = bytearray(len(a))
    for i, (first, second) in enumerate(zip(ga, gb)):
        if i < size[0] * mask_top:
            continue
        delta = max(-255, min(255, (second - first) * 3))
        channels[3 * i : 3 * i + 3] = bytes((max(delta, 0), max(-delta, 0), max(delta, 0)))
    save(channels, size, f"{platform}-channels.png")
    save(bytes(min(255, abs(x - y) * 3) for x, y in zip(a, b)), size, f"{platform}-rgb-difference.png")
    save(bytes((x + y) // 2 for x, y in zip(a, b)), size, f"{platform}-overlay.png")
    # Same source rectangle on both images; never align individual components.
    rect = "142x140+420+874" if platform == "android" else "213x174+630+1116"
    for source, suffix in [(sketch, "sketch"), (native, "native"), (ROOT / f"{platform}-channels.png", "channels")]:
        run(source, "-crop", rect, "+repage", ROOT / f"{platform}-component-{suffix}.png")
    manifest.append({
        "platform": platform,
        "sizePx": size,
        "maskedTopPx": mask_top,
        "gain": 3,
        "crop": rect,
        "sources": [{"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in (sketch, native)],
    })
(ROOT / "comparison-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
