#!/usr/bin/env python3
"""Prepare complete Android capture sets and small previews for the screenshot branch."""

import argparse
from pathlib import Path
import re
import shutil

from PIL import Image


SCREENS = {
    "01-schedule": "Zeitplan",
    "02-artists": "Künstler",
    "03-locations": "Orte",
    "04-more": "Mehr",
}


def prepare(source, output, repository, run_url, commit):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Expected an owner/repository name")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected a full source commit ID")
    if not re.fullmatch(rf"https://github\.com/{re.escape(repository)}/actions/runs/[0-9]+", run_url):
        raise ValueError("Expected a workflow URL in the source repository")
    if output.exists():
        raise ValueError(f"Output already exists: {output}")

    captures = []
    for device in ("phone", "tablet"):
        for locale in ("de", "en"):
            for appearance in ("light", "dark"):
                for screen in SCREENS:
                    relative = Path(device, locale, appearance, screen + ".png")
                    path = source / relative
                    with Image.open(path) as image:
                        if image.format != "PNG":
                            raise ValueError(f"Not a PNG: {path}")
                        image.verify()
                    captures.append(relative)

    # Validate every input before creating a publishable output directory.
    for relative in captures:
        original = output / "android/screenshots" / relative
        preview = output / "android/thumbnails" / relative
        original.parent.mkdir(parents=True, exist_ok=True)
        preview.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / relative, original)
        with Image.open(source / relative) as image:
            width = min(image.width, 360 if relative.parts[0] == "phone" else 480)
            height = round(image.height * width / image.width)
            image.resize((width, height), Image.Resampling.LANCZOS).save(preview, optimize=True)

    raw = f"https://raw.githubusercontent.com/{repository}/screenshots/android"
    lines = [
        "# Android-Screenshots",
        "",
        f"[Erfolgreicher Workflow-Lauf]({run_url}) · "
        f"[App-Stand {commit[:7]}](https://github.com/{repository}/commit/{commit})",
        "",
        "Die Vorschaubilder öffnen die Originale in voller Auflösung.",
    ]
    for device, device_title, width in (("phone", "Telefon", 150), ("tablet", "Tablet", 220)):
        for locale, language in (("de", "Deutsch"), ("en", "Englisch")):
            for appearance, theme in (("light", "Hell"), ("dark", "Dunkel")):
                lines += ["", f"## {device_title} · {language} · {theme}", "", '<p align="center">']
                for screen, title in SCREENS.items():
                    path = f"{device}/{locale}/{appearance}/{screen}.png"
                    lines.append(
                        f'  <a href="{raw}/screenshots/{path}">'
                        f'<img src="{raw}/thumbnails/{path}" width="{width}" '
                        f'alt="{title}, {device_title}, {language}, {theme}"></a>'
                    )
                lines += ["</p>"]
    (output / "README.md").write_text("\n".join(lines) + "\n")
    print(f"Prepared {len(captures)} originals and {len(captures)} previews in {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    prepare(args.source, args.output, args.repository, args.run_url, args.commit)
