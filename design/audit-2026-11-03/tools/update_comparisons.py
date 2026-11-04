"""Refresh the existing Sketch comparison report from lossless, untrimmed exports."""
from argparse import ArgumentParser
from datetime import date
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageChops
from channel_difference import channel_difference


def image_record(path, root):
    with Image.open(path) as image:
        width, height = image.size
    return {
        "src": path.relative_to(root).as_posix(),
        "width": width,
        "height": height,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def save_lossless(image, path, root):
    image = image.convert("RGB")
    if path.suffix == ".webp":
        image.save(path, lossless=True, method=4)
    else:
        image.save(path)
    with Image.open(path) as saved:
        if ImageChops.difference(image, saved.convert("RGB")).getbbox():
            raise ValueError(f"Lossless verification failed: {path}")
    return image_record(path, root)


def update(manifest, exports, baseline, review_date):
    root = manifest.parent
    data = json.loads(manifest.read_text())
    top = data["metadata"]["channelDifference"]["mask"]["topSourcePixels"]
    sources = []
    for pair in data["comparisons"]:
        export = exports / (pair["frame"] + "@3x.png")
        reference = root / pair["runtime"]["src"]
        if hashlib.sha256(reference.read_bytes()).hexdigest() != pair["runtime"]["sha256"]:
            raise ValueError(f"Reference checksum changed: {reference}")
        with Image.open(export) as image, Image.open(reference) as native:
            if image.size != native.size:
                raise ValueError(f"Dimensions differ: {export}: {image.size} / {native.size}")
            if not 0 <= top <= native.height:
                raise ValueError("System-bar mask is outside the source image")
        previous = baseline / export.name if baseline else None
        if previous:
            with Image.open(previous) as image, Image.open(reference) as native:
                if image.size != native.size:
                    raise ValueError(f"Baseline dimensions differ: {previous}")
        sources.append((pair, export, reference, previous))

    assets = root / "assets"
    for pair, export, reference, previous in sources:
        key = pair["key"]
        with Image.open(export) as image, Image.open(reference) as native:
            a, b = image.convert("RGB"), native.convert("RGB")
            pair["sketch"] = save_lossless(a, assets / f"sketch-{key}.webp", root)
            pair["difference"] = save_lossless(
                ImageChops.difference(a, b).point(lambda value: min(255, value * 3)),
                assets / f"diff-{key}.webp", root,
            )
            pair["overlay"] = save_lossless(
                Image.blend(a, b, 0.5), assets / f"overlay-{key}.webp", root,
            )
            pair["signedDifference"] = save_lossless(
                channel_difference(a, b, top), assets / f"signed-gray-{key}.png", root,
            )
            if previous:
                with Image.open(previous) as old:
                    pair["componentBaseline"] = save_lossless(
                        old, assets / f"baseline-{review_date}-{key}.webp", root,
                    )
                    pair["componentBaselineDifference"] = save_lossless(
                        channel_difference(old, b, top),
                        assets / f"baseline-channels-{review_date}-{key}.png", root,
                    )
        print(f"Updated {key}", flush=True)

    data["metadata"]["reviewDate"] = review_date
    data["metadata"]["runtimeReferenceDate"] = "2026-11-03"
    data["metadata"]["reviewScope"] = (
        "Gemeinsame iOS-Sketch-Stile und Komponenten, danach erneuter Kanalvergleich "
        "aller 22 Zustände gegen dieselben datierten Simulatorreferenzen. "
        "Die Bilder belegen keinen neuen Lauf eines späteren App-Builds."
    )
    if baseline:
        data["metadata"]["componentBaselineDate"] = review_date
    manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    (root / "data.js").write_text(
        "window.AUDIT = " + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + ";\n"
    )


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--exports", type=Path, required=True, help="Folder containing <frame-ID>@3x.png")
    parser.add_argument("--baseline", type=Path, help="Same frame exports before component changes")
    parser.add_argument("--review-date", required=True, help="Review date in the intended local timezone, YYYY-MM-DD")
    parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().parents[1] / "manifest.json")
    args = parser.parse_args()
    date.fromisoformat(args.review_date)
    update(args.manifest.resolve(), args.exports.resolve(), args.baseline.resolve() if args.baseline else None, args.review_date)
