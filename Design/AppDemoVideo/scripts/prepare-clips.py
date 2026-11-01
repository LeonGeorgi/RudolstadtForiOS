"""Trim native 60 fps captures; preserve the original animation speed."""
from pathlib import Path
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(root / 'scripts/normalize-captures.py')], check=True)
cuts = json.loads((root / 'scripts/cuts.json').read_text())
selected = set(sys.argv[1:]) or set(cuts)
for name, cut in cuts.items():
    if name not in selected:
        continue
    inputs = []
    filters = []
    for i, segment in enumerate(cut['segments']):
        start, duration = segment[:2]
        source = root / 'captures/normalized' / (segment[2] if len(segment) > 2 else cut['source'])
        if not source.exists():
            raise SystemExit(f'Missing native recording: {source}')
        inputs.extend(['-ss', str(start), '-t', str(duration), '-i', str(source)])
        filters.append(f'[{i}:v]setpts=PTS-STARTPTS,fps=60,setsar=1[v{i}]')
    labels = ''.join(f'[v{i}]' for i in range(len(cut['segments'])))
    filters.append(f'{labels}concat=n={len(cut["segments"])}:v=1:a=0,tpad=stop_mode=clone:stop_duration={cut["duration"]}[out]')
    destination = root / 'public/clips' / f'{name}.mp4'
    subprocess.run([
        'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', *inputs,
        '-filter_complex', ';'.join(filters), '-map', '[out]', '-an',
        '-t', str(cut['duration']), '-c:v', 'libx264', '-crf', '17',
        '-preset', 'fast', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(destination)
    ], check=True)
    print(f'{name}: {cut["duration"]}s', flush=True)
