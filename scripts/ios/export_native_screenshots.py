#!/usr/bin/env python3
"""Normalize named XCTest attachments to the existing screenshot directory layout."""
import argparse
import json
from pathlib import Path
import shutil

SCREENS = ("01-schedule", "02-artists", "03-locations", "04-artist-detail", "05-friends", "06-artist-world-map", "07-schedule-dark")


def export(source, output, locales, device, capture_id):
    manifest = json.loads((source / "manifest.json").read_text())
    found = {}
    for test in manifest:
        for attachment in test["attachments"]:
            name = attachment["suggestedHumanReadableName"]
            for locale in locales:
                for screen in SCREENS:
                    tag = f"native-{locale}-{screen}"
                    if name == tag or name.startswith(tag + ".") or name.startswith(tag + "_"):
                        key = (locale, screen)
                        if key in found:
                            raise ValueError(f"Duplicate screenshot: {key}")
                        path = source / attachment["exportedFileName"]
                        if path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
                            raise ValueError(f"Invalid PNG: {path}")
                        found[key] = path
    expected = {(locale, screen) for locale in locales for screen in SCREENS}
    if set(found) != expected:
        raise ValueError(f"Incomplete XCTest screenshot set; missing {sorted(expected - set(found))}")
    for locale in locales:
        directory = output / locale / device / capture_id
        directory.mkdir(parents=True, exist_ok=False)
        for screen in SCREENS:
            shutil.copy2(found[locale, screen], directory / (screen + ".png"))
    print(f"Exported {len(found)} complete XCTest screenshots")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--locales", nargs="+", choices=["de", "en"], default=["de", "en"])
    parser.add_argument("--device", required=True)
    parser.add_argument("--capture-id", required=True)
    args = parser.parse_args()
    export(args.source, args.output, args.locales, args.device, args.capture_id)
