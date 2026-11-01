"""Preserve long held frames in variable-rate simulator recordings before cuts."""
from pathlib import Path
import json
import subprocess

root = Path(__file__).resolve().parents[1]
cuts = json.loads((root / 'scripts/cuts.json').read_text())
required = {}
for cut in cuts.values():
    for segment in cut['segments']:
        filename = segment[2] if len(segment) > 2 else cut['source']
        required[filename] = max(required.get(filename, 0), segment[0] + segment[1])
destination = root / 'captures/normalized'
destination.mkdir(parents=True, exist_ok=True)
for filename, end in required.items():
    source = root / 'captures' / filename
    normalized = destination / filename
    if normalized.exists() and (not source.exists() or normalized.stat().st_mtime >= source.stat().st_mtime):
        cached_duration = float(subprocess.check_output([
            'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
            '-of', 'csv=p=0', str(normalized)
        ]))
        if cached_duration >= end:
            continue
    if not source.exists():
        raise SystemExit(f'Missing native recording: {source}')
    subprocess.run([
        'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', str(source),
        '-t', str(end + 1), '-vf', 'fps=60:start_time=0', '-an',
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '14',
        '-pix_fmt', 'yuv420p', str(normalized)
    ], check=True)
    print(f'Normalized {filename}', flush=True)
