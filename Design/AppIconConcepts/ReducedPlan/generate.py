"""Reduced plan marks with original festival glyph outlines, no font substitutes."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
NS = 'http://www.w3.org/2000/svg'
source = ROOT.parent / 'Refined/08-ru-signet.icon/Assets/Originalschriftzug.svg'
data = ET.parse(source).find(f'.//{{{NS}}}path').get('d')
glyphs = []
for contour in data.split('Z'):
    values = [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', contour)]
    if values:
        glyphs.append(list(zip(values[::2], values[1::2])))
assert len(glyphs) == 2
IVORY = '#FFF9EF'
ORANGE = '#DB7428'
PLUM = '#68245E'


def glyph(indices, box, color):
    selected = [glyphs[i] for i in indices]
    xs = [x for contour in selected for x, _ in contour]
    ys = [y for contour in selected for _, y in contour]
    x0, y0, width, height = box
    scale = min(width/(max(xs)-min(xs)), height/(max(ys)-min(ys)))
    left = x0+(width-(max(xs)-min(xs))*scale)/2
    top = y0+(height-(max(ys)-min(ys))*scale)/2
    paths = []
    for contour in selected:
        points = [f'{left+(x-min(xs))*scale:.3f},{top+(max(ys)-y)*scale:.3f}' for x, y in contour]
        paths.append('M'+' L'.join(points)+' Z')
    return f'<path fill="{color}" d="{" ".join(paths)}"/>'


# A single fold: a generous cover and one narrow return. No map printing.
a = f'<path fill="{ORANGE}" d="M646 233 L777 186 Q797 179 797 203 V724 Q797 744 779 751 L658 796 Z"/>'
a += f'<path fill="{IVORY}" d="M222 185 Q222 163 244 170 L651 279 V826 Q651 848 630 842 L240 738 Q222 733 222 713 Z"/>'
a += glyph([0, 1], (291, 316, 285, 355), PLUM)

# A closed pocket plan: one cover and one folded corner.
b = f'<path fill="{ORANGE}" d="M296 174 H594 L738 318 V825 Q738 850 713 850 H296 Q271 850 271 825 V199 Q271 174 296 174 Z"/>'
b += f'<path fill="{IVORY}" d="M594 174 V292 Q594 318 620 318 H738 Z"/>'
b += glyph([0], (371, 352, 266, 365), IVORY)

# The paper object disappears: the paired letterforms are the mark.
c = glyph([0, 1], (275, 178, 464, 668), IVORY)
# Fold only the top-right portion of the u into the accent color.
c += '<defs><clipPath id="letter-fold"><path d="M594 178 H775 V379 Z"/></clipPath></defs>'
c += '<g clip-path="url(#letter-fold)">'+glyph([0, 1], (275, 178, 464, 668), ORANGE)+'</g>'

studies = [
    ('01-plan-ru', '1 · Eine Falte + ru', a),
    ('02-taschenplan-r', '2 · Umschlag + r', b),
    ('03-gefaltetes-ru', '3 · Nur das gefaltete ru', c),
]
for slug, title, graphic in studies:
    (ROOT/f'{slug}.svg').write_text(f'<svg xmlns="{NS}" width="1024" height="1024" viewBox="0 0 1024 1024"><title>{title}</title>{graphic}</svg>\n')

board = [f'<svg xmlns="{NS}" width="1440" height="900" viewBox="0 0 1440 900"><rect width="1440" height="900" fill="#F6F4F1"/>']
board += ['<text x="54" y="66" font-family="Helvetica" font-size="29" fill="#332333">Festivalplan – auf ein Zeichen reduziert</text>']
for index, (_, title, graphic) in enumerate(studies):
    x = 42+index*464
    board += [f'<text x="{x+12}" y="126" font-family="Helvetica" font-size="23" fill="#332333">{title}</text>']
    board += [f'<rect x="{x}" y="158" width="428" height="638" fill="{PLUM}"/>']
    board += [f'<g transform="translate({x+12} 194) scale(.39453125)">{graphic}</g>']
    for size, offset in [(48, 131), (32, 265)]:
        board += [f'<g transform="translate({x+offset} 662) scale({size/1024})">{graphic}</g>']
        board += [f'<text x="{x+offset+size/2}" y="748" text-anchor="middle" font-family="Helvetica" font-size="17" fill="{IVORY}">{size} px</text>']
board += ['<text x="54" y="852" font-family="Helvetica" font-size="19" fill="#665966">Flache SVG-Formstudien · Originalkonturen · noch ohne Icon-Composer-Material</text></svg>']
(ROOT/'vergleich.svg').write_text(''.join(board))
print('Three reduced SVG marks and comparison at 48 and 32 pixels.')
