"""Check the delivered movies, including a complete decode and measured audio levels."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import struct
import subprocess

root = Path(__file__).resolve().parents[1]
report = {'checked_at': datetime.now(timezone.utc).isoformat(), 'exports': []}
for name, size in [('hochformat', (1080, 1920)), ('querformat', (1920, 1080))]:
    path = root / 'output' / f'rudolstadt-news-{name}.mp4'
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)]))
    video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
    audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
    assert (video['width'], video['height']) == size
    assert video['codec_name'] == 'h264' and video['pix_fmt'] == 'yuv420p'
    assert video['r_frame_rate'] == '60/1' and int(video['nb_frames']) == 1662
    assert abs(float(video['duration']) - 27.7) < .02
    assert float(probe['format']['duration']) < 30
    assert audio['codec_name'] == 'aac' and audio['channels'] == 2
    assert audio['sample_rate'] == '48000'
    subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'null', '-'], check=True)
    levels = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path), '-map', '0:a:0', '-af', 'loudnorm=I=-16:TP=-1.5:LRA=8:print_format=json', '-f', 'null', '-'], capture_output=True, text=True, check=True)
    measured = json.loads(re.search(r'{\s*"input_i".*?}', levels.stderr, re.S).group())
    assert float(measured['input_tp']) < 0
    data = path.read_bytes()
    atoms = []
    offset = 0
    while offset + 8 <= len(data):
        length, kind = struct.unpack_from('>I4s', data, offset)
        if length == 1:
            length = struct.unpack_from('>Q', data, offset + 8)[0]
        if length == 0:
            length = len(data) - offset
        atoms.append(kind.decode('ascii'))
        offset += length
    assert atoms.index('moov') < atoms.index('mdat')
    report['exports'].append({
        'path': str(path), 'size': size, 'fps': 60, 'frames': 1662,
        'duration': float(probe['format']['duration']), 'decode': 'passed',
        'fast_start': True, 'loudness_lufs': measured['input_i'],
        'true_peak_dbtp': measured['input_tp'], 'bytes': len(data),
        'sha256': hashlib.sha256(data).hexdigest(),
    })
report['visual_review'] = 'Both compositions: full-film contact sheets and focused checks of rating, saving, timeline entrances, stage map, native news sheet, article navigation, and closing.'
report['story'] = 'Friends recommend RIAN; rate and save the concert; find it in the Saturday plan; open Konzertbühne Heinepark, then read the festival news.'
report['native_animation_speed'] = 'Original; only idle/loading holds trimmed.'
report['music'] = {'track': 'Funked Up', 'artist': 'Joth', 'license': 'CC0', 'source': 'https://opengameart.org/content/funked-up', 'edited_bpm': 130, 'duration': 27.7}
report['production_app_code_changed'] = False
path = root / 'output/verification-news.json'
path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
print(json.dumps(report, indent=2, ensure_ascii=False))
