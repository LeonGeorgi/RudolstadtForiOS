"""Edit the CC0 Joth track into a 130 BPM, 27.7-second product film cue."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
source = root / 'captures/music-candidates/funked-up.mp3'
if not source.exists():
    raise SystemExit('Download Funked Up by Joth from the source documented in README.md.')
speed = 130 / 116
body_end = 56 * 60 / 130
subprocess.run([
    'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', str(source),
    '-filter_complex',
    f'[0:a]atrim=start=0.22,asetpts=PTS-STARTPTS,atempo={speed},asplit=2[a][b];'
    f'[a]atrim=end={body_end},afade=t=in:d=0.008[body];'
    f'[b]atrim=start={body_end}:duration=0.24,asetpts=PTS-STARTPTS,'
    'afade=t=out:st=0.06:d=0.18,apad=pad_dur=1.61,'
    'aecho=0.8:0.85:115|230|345:0.32|0.19|0.11,atrim=duration=1.846154[tail];'
    '[body][tail]concat=n=2:v=0:a=1,apad,atrim=duration=27.7,'
    'afade=t=out:st=27.25:d=0.45,loudnorm=I=-14:TP=-1.5:LRA=7[out]',
    '-map', '[out]', '-ar', '48000', '-ac', '2', str(root / 'public/soundtrack.wav')
], check=True)
print('Funked Up — Joth, CC0; 130 BPM; 27.7 seconds.')
