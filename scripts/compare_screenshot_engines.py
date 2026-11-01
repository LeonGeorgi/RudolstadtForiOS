#!/usr/bin/env python3
"""Run Maestro and native capture sequentially against the same prebuilt app/device."""
import argparse
import hashlib
import html
import json
import os
import signal
from pathlib import Path
import statistics
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
SCREENS = {
    "android": ("01-schedule", "02-artists", "03-locations", "04-more"),
    "ios": ("01-schedule", "02-artists", "03-locations", "04-artist-detail", "05-friends", "06-artist-world-map", "07-schedule-dark"),
}


def command(*args):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return result.stdout.strip()


def inspect_images(directory, platform, locales):
    images = {}
    for path in directory.rglob("*.png"):
        parts = path.relative_to(directory).parts
        key = "/".join((parts[0], parts[1], path.name) if platform == "android" else (parts[0], path.name))
        if key in images:
            raise ValueError(f"Duplicate image: {key}")
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError(f"Invalid PNG: {path}")
        images[key] = {"path": str(path), "size": list(struct.unpack(">II", data[16:24])), "sha256": hashlib.sha256(data).hexdigest()}
    expected = {f"{locale}/{appearance + '/' if appearance else ''}{screen}.png"
                for locale in locales
                for appearance in (("light", "dark") if platform == "android" else ("",))
                for screen in SCREENS[platform]}
    if set(images) != expected:
        raise ValueError(f"Screenshot set mismatch: missing {sorted(expected - set(images))}, extra {sorted(set(images) - expected)}")
    return images


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=SCREENS)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rounds", type=int, choices=range(1, 6), default=2)
    parser.add_argument("--locales", nargs="+", choices=("de", "en"), default=["de", "en"])
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env["LOCALES"] = " ".join(args.locales)
    env["CAPTURE_ID"] = "comparison"
    if args.platform == "android":
        device = env["ANDROID_SERIAL"]
        adb = str(Path(env.get("ANDROID_HOME", "")) / "platform-tools/adb") if env.get("ANDROID_HOME") else "adb"
        device_info = command(adb, "-s", device, "shell", "getprop", "ro.build.fingerprint")
        app = Path(env.get("PREBUILT_APK_PATH", ROOT / "androidApp/build/outputs/apk/debug/androidApp-debug.apk"))
        scripts = {engine: "android/capture-screenshots.sh" for engine in ("native", "maestro")}
    else:
        device = env["DEVICE_ID"]
        device_info = command("xcrun", "simctl", "list", "devices", "--json")
        app = Path(env["PREBUILT_APP_PATH"]) / "Rudolstadt"
        if not Path(env["XCTEST_RUN_FILE"]).is_file():
            parser.error("Build native tests first; set XCTEST_RUN_FILE")
        scripts = {"native": "ios/capture-native-screenshots.sh", "maestro": "ios/capture-app-store-screenshots.sh"}
    report = {"platform": args.platform, "device": device, "device_info": device_info,
              "app_sha256": hashlib.sha256(app.read_bytes()).hexdigest(),
              "maestro": command("maestro", "--version"), "locales": args.locales,
              "method": "Prebuilt app; boot excluded, install/setup/driver startup/export included. Alternating order; no discarded warmup or automatic native retries.",
              "runs": []}
    if args.platform == "ios":
        report["native_version"] = command("xcodebuild", "-version")
    else:
        report["native_version"] = "UI Automator 2.4.0 / AndroidX Test runner 1.7.0"
    for round_number in range(1, args.rounds + 1):
        order = ("maestro", "native") if round_number % 2 else ("native", "maestro")
        for engine in order:
            name = f"round-{round_number}-{engine}"
            run_root = output / name
            run_root.mkdir()
            capture = run_root / "screenshots"
            env.update(SCREENSHOT_ENGINE=engine, OUTPUT_ROOT=str(capture), DIAGNOSTICS_ROOT=str(run_root / "diagnostics"))
            print(f"Starting {name}", flush=True)
            started = time.monotonic()
            with (run_root / "capture.log").open("w") as log:
                process = subprocess.Popen(["bash", str(ROOT / "scripts" / scripts[engine])], env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                try:
                    status = process.wait(timeout=900)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                    status = 124
            run = {"round": round_number, "engine": engine, "seconds": round(time.monotonic() - started, 2), "exit_code": status, "images": {}}
            try:
                run["images"] = inspect_images(capture, args.platform, args.locales)
            except ValueError as error:
                run["validation_error"] = str(error)
            run["success"] = status == 0 and "validation_error" not in run
            report["runs"].append(run)
            (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(f"{name}: {run['seconds']}s, success={run['success']}, images={len(run['images'])}", flush=True)
    rows = ["| Engine | Complete runs | Median seconds |", "| --- | ---: | ---: |"]
    for engine in ("maestro", "native"):
        runs = [run for run in report["runs"] if run["engine"] == engine]
        passed = [run for run in runs if run["success"]]
        median = f"{statistics.median(run['seconds'] for run in passed):.2f}" if passed else "—"
        rows.append(f"| {engine} | {len(passed)}/{len(runs)} | {median} |")
    summary = f"# {args.platform} screenshot comparison\n\n" + "\n".join(rows) + "\n\n" + report["method"] + "\n\nSmall local/CI sample: this does not establish long-term reliability. Review the paired images in gallery.html; timing and PNG completeness do not establish visual equivalence.\n"
    (output / "summary.md").write_text(summary)
    gallery = ["<!doctype html><meta charset='utf-8'><title>Screenshot comparison</title><style>body{font:16px system-ui}table{border-collapse:collapse}td,th{padding:12px}img{width:260px;max-width:40vw}figure{margin:0}</style><h1>Screenshot comparison</h1><p>Review navigation, scroll positions, loaded maps/images and appearance.</p>"]
    for round_number in range(1, args.rounds + 1):
        runs = {r["engine"]: r for r in report["runs"] if r["round"] == round_number}
        gallery.append(f"<h2>Round {round_number}</h2><table><tr><th>Scene</th><th>Maestro</th><th>Native</th></tr>")
        for key in sorted(set().union(*(r["images"] for r in runs.values()))):
            gallery.append(f"<tr><th>{html.escape(key)}</th>")
            for engine in ("maestro", "native"):
                image = runs[engine]["images"].get(key)
                src = html.escape(str(Path(image["path"]).relative_to(output)), quote=True) if image else None
                gallery.append(f'<td><a href="{src}"><img loading="lazy" src="{src}"></a></td>' if src else "<td>Missing</td>")
            gallery.append("</tr>")
        gallery.append("</table>")
    (output / "gallery.html").write_text("\n".join(gallery))
    print(summary)
    return 0 if all(run["success"] for run in report["runs"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
