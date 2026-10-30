"""Render editable Android icon concepts without changing launcher resources.

Requires Python 3 and rsvg-convert. Run from any directory.
"""
from copy import deepcopy
from pathlib import Path
import math
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)


def element(tag, attrs=None, text=None):
    node = ET.Element(f'{{{NS}}}{tag}', {k: str(v) for k, v in (attrs or {}).items()})
    node.text = text
    return node


def points(path):
    values = list(map(float, re.findall(r'-?\d+(?:\.\d+)?', path)))
    return list(zip(values[::2], values[1::2]))


def fit(paths, radius=31.5):
    coordinates = [p for path in paths for p in points(path)]
    xs, ys = zip(*coordinates)
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    scale = radius / max(math.hypot(x-cx, y-cy) for x, y in coordinates)
    output = []
    for path in paths:
        contour = points(path)
        output.append('M' + ' L'.join(
            f'{54+(x-cx)*scale:.3f},{54+(y-cy)*scale:.3f}' for x,y in contour
        ) + ' Z')
    return output


def path_node(path, fill):
    return element('path', {'d': path, 'fill': fill, 'fill-rule': 'evenodd'})


def artwork(paths, colors):
    group = element('g', {'id': 'artwork'})
    for path, color in zip(paths, colors):
        group.append(path_node(path, color))
    return group


original = ET.parse(ROOT.parent / 'launcher-icon.svg').getroot().find(f'{{{NS}}}path').get('d')
contours = re.findall(r'M[^M]*', original)
assert len(contours) == 14
# The existing wordmark contains one contour each for the initial r and u.
r, u = contours[1], contours[2]
assert max(x for x,y in points(r)) < 36
assert max(x for x,y in points(u)) < 45
ru = fit([r, u])

# A new ribbon-like capital R; a sloping baseline echoes the original wordmark.
ribbon = (
    'M34,80 L34,34 Q34,30 38,29 L54,25 '
    'Q74,21 74,41 Q74,53 63,59 L77,75 L63,78 L49,62 L46,63 '
    'L46,77 Z '
    'M46,40 L46,51 L54,49 Q62,47 62,42 Q62,36 55,38 Z'
)
# A folded programme/map: three clean panels and a single route.
map_shape = 'M28,35 L45,29 L62,35 L79,29 L79,73 L62,80 L45,74 L28,81 Z'
map_art = element('g', {
    'id': 'artwork',
    'transform': 'translate(54 54) scale(.86) translate(-54 -54)',
})
map_art.append(path_node(map_shape, '#FFFFFF'))
map_art.append(element('path', {'d': 'M45,29 V74 M62,35 V80', 'fill': 'none', 'stroke': '#782C74', 'stroke-width': '2.5'}))
map_art.append(element('path', {'d': 'M36,65 L52,51 L69,55', 'fill': 'none', 'stroke': '#F1B779', 'stroke-width': '4.3', 'stroke-linecap': 'round', 'stroke-linejoin': 'round'}))
map_art.append(element('circle', {'cx': '69', 'cy': '55', 'r': '4.5', 'fill': '#F1B779'}))

concepts = [
    ('a-original-pur', 'A', 'Original pur', 'Die vertraute Wortmarke, einfarbig.', '#782C74', artwork([original], ['#FFFFFF'])),
    ('b-original-hell', 'B', 'Original hell', 'Die gleiche Marke mit hellem Grund.', '#F1E7F0', artwork([original], ['#782C74'])),
    ('c-ru-signet', 'C', 'ru Signet', 'Zwei Originalbuchstaben, größer gesetzt.', '#782C74', artwork(ru, ['#FFFFFF', '#FFFFFF'])),
    ('d-ru-zweiklang', 'D', 'ru Zweiklang', 'Das Signet mit einem warmen Akzent.', '#492B55', artwork(ru, ['#FFF4E6', '#F1B779'])),
    ('e-r-als-band', 'E', 'R als Band', 'Ein eigenständiges, kompaktes Zeichen.', '#782C74', artwork([ribbon], ['#FFFFFF'])),
    ('f-festivalplan', 'F', 'Festivalplan', 'Ein Bildzeichen für Programm und Wege.', '#782C74', map_art),
]


def make_svg(stem, title, bg, art):
    svg = element('svg', {'width': '1024', 'height': '1024', 'viewBox': '0 0 108 108'})
    svg.append(element('title', text=title))
    svg.append(element('desc', text='Android-Icon-Entwurf. Die Außenform wird vom Launcher bestimmt.'))
    svg.append(element('rect', {'id': 'background', 'width': '108', 'height': '108', 'fill': bg}))
    svg.append(deepcopy(art))
    ET.indent(svg, space='  ')
    ET.ElementTree(svg).write(ROOT / f'{stem}.svg', encoding='utf-8', xml_declaration=True)
    # A full square store/inspection view of the middle 72dp viewport.
    svg.set('viewBox', '18 18 72 72')
    ET.ElementTree(svg).write(ROOT / f'{stem}-viewport.svg', encoding='utf-8', xml_declaration=True)
    subprocess.run(['rsvg-convert', str(ROOT / f'{stem}-viewport.svg'), '-o', str(ROOT / f'{stem}.png')], check=True)
    (ROOT / f'{stem}-viewport.svg').unlink()


for stem, letter, title, subtitle, bg, art in concepts:
    make_svg(stem, title, bg, art)

sheet = element('svg', {'width': '1800', 'height': '1320', 'viewBox': '0 0 1800 1320'})
defs = element('defs')
sheet.append(defs)
for name, shape in [
    ('circle', element('circle', {'cx': '54', 'cy': '54', 'r': '36'})),
    ('rounded', element('rect', {'x': '18', 'y': '18', 'width': '72', 'height': '72', 'rx': '22'})),
]:
    clip = element('clipPath', {'id': name})
    clip.append(shape)
    defs.append(clip)
sheet.append(element('rect', {'width': '1800', 'height': '1320', 'fill': '#F4F1F5'}))


def text(x, y, content, size=22, color='#2D2432', weight='400'):
    sheet.append(element('text', {
        'x': x, 'y': y, 'font-family': 'Helvetica Neue, Helvetica, Arial, sans-serif',
        'font-size': size, 'font-weight': weight, 'fill': color,
    }, content))


def icon(x, y, size, bg, art, mask='circle', mono=False):
    transform = f'translate({x-18*size/72} {y-18*size/72}) scale({size/72})'
    group = element('g', {'transform': transform})
    clipped = element('g', {'clip-path': f'url(#{mask})'})
    clipped.append(element('rect', {'width': '108', 'height': '108', 'fill': '#DED0EA' if mono else bg}))
    copy = deepcopy(art)
    copy.attrib.pop('id', None)
    if mono:
        for child in copy:
            if child.get('fill') != 'none':
                child.set('fill', '#DED0EA' if art is map_art and child.get('fill') == '#F1B779' else '#4E3462')
            if child.get('stroke'):
                # Fold lines and route become cutouts in the map's monochrome mask.
                child.set('stroke', '#DED0EA')
    clipped.append(copy)
    group.append(clipped)
    sheet.append(group)


text(70, 68, 'Rudolstadt / Android', 24, '#786B7D', '500')
text(68, 132, 'Sechs Vorschläge fürs App-Icon', 48, '#2D2432', '600')
text(70, 177, 'Ohne Farbverlauf · von der iOS-Wortmarke bis zum eigenständigen Zeichen', 24, '#786B7D')

for i, (stem, letter, title, subtitle, bg, art) in enumerate(concepts):
    col, row = i % 3, i // 3
    x, y = 70 + col * 574, 229 + row * 510
    text(x, y+35, f'{letter}  {title}', 30, '#2D2432', '600')
    text(x, y+74, subtitle, 21, '#786B7D')
    icon(x+6, y+112, 250, bg, art)
    icon(x+325, y+112, 94, bg, art, 'rounded')
    icon(x+325, y+249, 94, bg, art, mono=True)
    text(x+325, y+226, 'Form', 17, '#786B7D')
    text(x+325, y+363, 'Systemfarbe', 17, '#786B7D')
    icon(x+6, y+396, 48, bg, art)
    text(x+70, y+427, '48 px', 18, '#786B7D')
    icon(x+177, y+386, 64, bg, art)
    text(x+257, y+427, '64 px', 18, '#786B7D')

text(70, 1290, 'Entwürfe mit simulierten Launcher-Masken. Alle SVG-Dateien bleiben frei editierbar.', 20, '#786B7D')
ET.indent(sheet, space='  ')
ET.ElementTree(sheet).write(ROOT / 'vergleich.svg', encoding='utf-8', xml_declaration=True)
subprocess.run(['rsvg-convert', str(ROOT / 'vergleich.svg'), '-o', str(ROOT / 'vergleich.png')], check=True)
print(f'Rendered {len(concepts)} concepts and comparison sheet in {ROOT}')
