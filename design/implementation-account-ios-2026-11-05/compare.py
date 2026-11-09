"""Compare unaligned, unscaled 3x Sketch and simulator captures."""
from argparse import ArgumentParser
from pathlib import Path
import json
import hashlib
from PIL import Image, ImageOps, ImageChops, ImageDraw, ImageFont

PAIRS = {'friends-login': 'login', 'email': 'email', 'key-login': 'key-login',
         'anonymous-account': 'anonymous-account', 'key-management': 'key-management',
         'sync': 'sync', 'revoked-test-key': 'key-display'}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def compare(native, reference, output):
    output.mkdir(parents=True, exist_ok=True)
    rows = []
    for screen, design in PAIRS.items():
        a, b = reference / (design + '.png'), native / (screen + '.png')
        if not a.exists() or not b.exists():
            rows.append({'screen': screen, 'compared': False, 'reason': 'capture missing'})
            continue
        original_a, original_b = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
        if original_a.size != original_b.size:
            raise ValueError(f'Dimensions differ for {screen}: {original_a.size}, {original_b.size}')
        gray_a, gray_b = ImageOps.grayscale(original_a), ImageOps.grayscale(original_b)
        magenta, green = ImageChops.subtract(gray_b, gray_a), ImageChops.subtract(gray_a, gray_b)
        channels = Image.merge('RGB', (magenta, green, magenta))
        ImageDraw.Draw(channels).rectangle((0, 0, channels.width - 1, 185), fill='black')
        channels.save(output / (screen + '-channels.png'))
        ImageChops.difference(original_a, original_b).save(output / (screen + '-rgb.png'))
        Image.blend(original_a, original_b, 0.5).save(output / (screen + '-overlay.png'))
        sheet = Image.new('RGB', (1206, 914), 'white')
        draw = ImageDraw.Draw(sheet)
        for index, (label, img) in enumerate([('Sketch', original_a), ('Simulator', original_b), ('Differenz', channels)]):
            draw.text((index * 402 + 12, 12), label, fill='black')
            sheet.paste(img.resize((402, 874), Image.Resampling.LANCZOS), (index * 402, 40))
        sheet.save(output / (screen + '-comparison.png'))
        rows.append({'screen': screen, 'compared': True, 'pixels': list(original_a.size),
                     'reference': str(a), 'reference_sha256': sha(a), 'native': str(b), 'native_sha256': sha(b)})
    (output / 'comparisons.json').write_text(json.dumps(rows, indent=2) + '\n')
    print(f'Compared {sum(r["compared"] for r in rows)} states')

if __name__ == '__main__':
    p = ArgumentParser()
    p.add_argument('native', type=Path)
    p.add_argument('reference', type=Path)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    compare(args.native, args.reference, args.output)
