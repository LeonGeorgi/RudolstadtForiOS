"""Flat SVG form studies, reusing the exact traced festival wordmark."""
from pathlib import Path
import math
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
NS = 'http://www.w3.org/2000/svg'
source = ROOT.parent / 'Refined/07-original-pur.icon/Assets/Originalschriftzug.svg'
d = ET.parse(source).find(f'.//{{{NS}}}path').get('d')
tokens = re.findall(r'[MLZ]|-?\d+(?:\.\d+)?', d)
contours = []
points = []
i = 0
while i < len(tokens):
    command = tokens[i]
    i += 1
    if command == 'Z':
        contours.append(points)
        points = []
    else:
        points.append((float(tokens[i]), float(tokens[i + 1])))
        i += 2
assert len(contours) == 14
xmin = min(x for contour in contours for x, y in contour)
xmax = max(x for contour in contours for x, y in contour)
ymin = min(y for contour in contours for x, y in contour)
ymax = max(y for contour in contours for x, y in contour)
ASPECT = (xmax - xmin) / (ymax - ymin)
PLUM = '#68245E'
ORANGE = '#CF7138'
WHITE = '#FFFEFB'
LAVENDER = '#D9CDE1'


def project(quad, u, v):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = quad
    dx1, dx2, dx3 = x1-x2, x3-x2, x0-x1+x2-x3
    dy1, dy2, dy3 = y1-y2, y3-y2, y0-y1+y2-y3
    if abs(dx3) + abs(dy3) < 1e-9:
        g = h = 0
    else:
        den = dx1*dy2-dx2*dy1
        g = (dx3*dy2-dx2*dy3)/den
        h = (dx1*dy3-dx3*dy1)/den
    a, b = x1-x0+g*x1, x3-x0+h*x3
    c, e = y1-y0+g*y1, y3-y0+h*y3
    return ((a*u+b*v+x0)/(g*u+h*v+1), (c*u+e*v+y0)/(g*u+h*v+1))


def logo(quad, center_y=.52, fraction=.80):
    width = (math.dist(quad[0], quad[1])+math.dist(quad[3], quad[2]))/2
    height = (math.dist(quad[0], quad[3])+math.dist(quad[1], quad[2]))/2
    du = fraction
    dv = width*du/ASPECT/height
    if dv > .77:
        dv = .77
        du = height*dv*ASPECT/width
    u0, v0 = .5-du/2, center_y-dv/2
    subpaths = []
    for contour in contours:
        mapped = []
        for x, y in contour:
            u = u0 + (x-xmin)/(xmax-xmin)*du
            v = v0 + (ymax-y)/(ymax-ymin)*dv
            px, py = project(quad, u, v)
            mapped.append(f'{px:.2f},{py:.2f}')
        subpaths.append('M'+' L'.join(mapped)+' Z')
    return f'<path fill="{PLUM}" fill-rule="evenodd" d="{" ".join(subpaths)}"/>'


def panel(quad, color):
    p = ' '.join(f'{x},{y}' for x, y in quad)
    return f'<polygon points="{p}" fill="{color}" stroke="{PLUM}" stroke-width="2.4" stroke-linejoin="round"/>'


def route(d, stops, color=WHITE, width=12):
    out = f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'
    for x, y in stops:
        out += f'<circle cx="{x}" cy="{y}" r="14" fill="{color}"/>'
    return out


studies = []
q1 = [(130,170),(450,220),(450,730),(130,680)]
q2 = [(450,220),(620,135),(620,645),(450,730)]
q3 = [(620,135),(890,200),(890,710),(620,645)]
a = panel(q2, PLUM)+panel(q3, ORANGE)+panel(q1, WHITE)
a += route('M505 350 C530 375 565 480 610 487 C665 495 698 376 745 395 C790 415 740 550 814 586', [(530,390),(745,395),(814,586)])
a += logo(q1)
studies.append(('a-z-faltung', 'A · Klare Z-Faltung', a))

cover = [(90,225),(300,145),(315,600),(70,680)]
q1 = [(300,145),(500,220),(515,675),(315,600)]
q2 = [(500,220),(720,155),(735,610),(515,675)]
q3 = [(720,155),(935,220),(950,675),(735,610)]
b = panel(q1, '#F6F1F7')+panel(q2, WHITE)+panel(q3, '#F6F1F7')
clip_polygons = ''.join('<polygon points="'+' '.join(f'{x},{y}' for x,y in q)+'"/>' for q in [q1,q2,q3])
b += '<defs><clipPath id="b-map-print">'+clip_polygons+'</clipPath></defs><g clip-path="url(#b-map-print)">'
blocks = [
    [(329,257),(378,277),(376,350),(330,333)],
    [(404,298),(468,323),(466,396),(404,372)],
    [(537,277),(599,254),(626,323),(550,348)],
    [(566,509),(635,491),(656,557),(586,582)],
    [(755,294),(817,314),(812,389),(753,367)],
    [(824,486),(902,510),(913,586),(833,566)],
]
for block in blocks:
    b += '<polygon points="'+' '.join(f'{x},{y}' for x,y in block)+'" fill="#E2D9E7"/>'
b += '<path d="M313 221 C410 249 430 376 540 399 S730 454 943 613" stroke="#CBBED7" stroke-width="38" fill="none"/>'
b += route('M331 398 C392 396 394 537 472 549 S578 392 653 415 S738 525 821 462 S886 391 928 424', [], ORANGE, 17)
for x,y in [(349,404),(472,549),(653,415),(908,412)]:
    b += f'<circle cx="{x}" cy="{y}" r="16" fill="{PLUM}" stroke="{WHITE}" stroke-width="4"/>'
b += '</g>'+panel(cover, WHITE)+logo(cover, fraction=.82)
studies.append(('b-aufgeklappter-stadtplan', 'B · Aufgeklappter Stadtplan', b))

q1 = [(165,200),(515,100),(450,770),(120,700)]
q2 = [(515,100),(675,280),(610,835),(450,770)]
q3 = [(675,280),(915,200),(850,755),(610,835)]
c = panel(q2, PLUM)+panel(q3, ORANGE)
c += route('M553 330 C578 385 567 550 620 591 C682 639 733 482 835 367', [(566,414),(620,591),(835,367)])
c += panel(q1, WHITE)+logo(q1, fraction=.86)
studies.append(('c-faecherplan', 'C · Dynamischer Fächerplan', c))

back = [(200,180),(640,100),(800,250),(370,330)]
inside = [(640,100),(875,280),(875,790),(640,610)]
cover = [(200,180),(680,240),(680,830),(200,760)]
d = panel(back, PLUM)+panel(inside, LAVENDER)
d += route('M689 340 C811 365 831 452 771 519 S753 671 844 712', [(761,374),(787,500),(844,712)], PLUM, 11)
d += panel(cover, WHITE)+logo(cover, center_y=.60, fraction=.78)
d += f'<path d="M245 173 L298 164 Q322 178 340 216 V385 L300 351 L260 385 V218 Q260 190 245 173 Z" fill="{ORANGE}"/>'
studies.append(('d-plan-mit-merkband', 'D · Persönlicher Taschenplan', d))

for slug, title, graphic in studies:
    (ROOT/f'{slug}.svg').write_text(f'<svg xmlns="{NS}" width="1024" height="900" viewBox="0 0 1024 900"><title>{title}</title>{graphic}</svg>\n')

board = [f'<svg xmlns="{NS}" width="1440" height="1390" viewBox="0 0 1440 1390"><rect width="1440" height="1390" fill="#F5F4F2"/>']
board.append('<text x="50" y="62" font-family="Helvetica" font-size="32" font-weight="500" fill="#332333">Vier Grafikideen für den Festivalplan</text>')
for index, (slug, title, graphic) in enumerate(studies):
    x, y = 35+(index%2)*710, 104+(index//2)*630
    board.append(f'<g transform="translate({x} {y}) scale(.65)">{graphic}</g>')
    board.append(f'<text x="{x+24}" y="{y+592}" font-family="Helvetica" font-size="23" fill="#332333">{title}</text>')
board.append('</svg>')
(ROOT/'planstudien-vergleich.svg').write_text(''.join(board))
print('Four flat source SVGs and one comparison sheet; original 14-contour lettering retained.')
