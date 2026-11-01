"""Render accordion icon variations. Requires Python 3, librsvg and ImageMagick."""
from copy import deepcopy
from pathlib import Path
import math
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
PURPLE = '#782C74'
PLUM = '#492B55'
CREAM = '#FFF5E9'
ORANGE = '#F1B779'


def node(tag, **attrs):
    return ET.Element(f'{{{NS}}}{tag}', {k.replace('_','-'):str(v) for k,v in attrs.items()})


def path(d, fill=CREAM, **attrs):
    return node('path', d=d, fill=fill, **attrs)


def line(d, width=3, fill=PURPLE, cutout=True):
    return path(d,'none',stroke=fill,stroke_width=width,stroke_linecap='round',stroke_linejoin='round',data_cutout=str(cutout).lower())


def dot(x,y,r=1.8):
    return node('circle',cx=x,cy=y,r=r,fill=PURPLE,data_cutout='true')


def group(*children, **attrs):
    result=node('g',**attrs);result.extend(children);return result


def paint(art, background, foreground=None):
    output=deepcopy(art)
    for item in output.iter():
        cutout=item.attrib.pop('data-cutout',None)=='true'
        for attr in ('fill','stroke'):
            if item.get(attr) and item.get(attr)!='none':
                if cutout: item.set(attr,background)
                elif foreground: item.set(attr,foreground)
    return output


def mask(art,prefix):
    result=node('mask',id=f'{prefix}-mask',maskUnits='userSpaceOnUse',x=0,y=0,width=108,height=108,style='mask-type:luminance')
    result.append(paint(art,'#000000','#FFFFFF'))
    return result


def foreground(art,prefix,bg,mono=False,color='#FFFFFF'):
    if mono:
        return node('rect',width=108,height=108,fill=color,mask=f'url(#{prefix}-mask)')
    return group(paint(art,bg),mask=f'url(#{prefix}-mask)')


def document(art,prefix,bg,mono=False):
    svg=node('svg',width=432,height=432,viewBox='0 0 108 108')
    defs=node('defs');defs.append(mask(art,prefix));svg.append(defs)
    if not mono: svg.append(node('rect',id='background',width=108,height=108,fill=bg))
    svg.append(group(foreground(art,prefix,bg,mono),id='artwork'))
    return svg


def normalize(art):
    # Measure the rendered alpha mask, including rounded strokes, then fit the
    # entire silhouette inside the 66dp safe circle with a small reserve.
    with tempfile.TemporaryDirectory(prefix='rudolstadt-accordion-') as folder:
        svg_file=Path(folder)/'mask.svg';png_file=Path(folder)/'mask.png'
        ET.ElementTree(document(art,'measure',PURPLE,True)).write(svg_file,encoding='utf-8')
        subprocess.run(['rsvg-convert',str(svg_file),'-o',str(png_file)],check=True)
        data=subprocess.check_output(['magick',str(png_file),'-depth','8','RGBA:-'])
    coords=[((i%432+.5)/4,(i//432+.5)/4) for i in range(432*432) if data[i*4+3]>127]
    xs,ys=zip(*coords)
    cx,cy=(min(xs)+max(xs))/2,(min(ys)+max(ys))/2
    radius=max(math.hypot(x-cx,y-cy) for x,y in coords)
    scale=32/radius
    return group(art,transform=f'translate(54 54) scale({scale:.7f}) translate({-cx:.5f} {-cy:.5f})')


# H1 preserves the previous motif, with the diagonal baseline and three stops.
left='M29,38 Q29,35 32,35 L38,33 Q41,32 41,36 V71 Q41,74 38,75 L32,77 Q29,78 29,74Z'
bellows='M42,39 L47,36 L52,38 L57,34 L62,36 L67,33 V69 L62,72 L57,70 L52,74 L47,72 L42,75Z'
right='M68,33 Q68,30 71,29 L77,27 Q80,26 80,30 V66 Q80,69 77,70 L71,72 Q68,73 68,69Z'

def original(warm=False):
    ends=ORANGE if warm else CREAM
    middle=CREAM if warm else ORANGE
    return group(path(left,ends),path(bellows,middle),path(right,ends),
        line('M47,40 V68 M57,38 V66',2.8),
        line('M34,43 V47 M34,55 V59 M34,67 V70',3),
        dot(74,39),dot(74,49),dot(74,59))

pur=group(
    path('M29,38 Q29,34 33,34 H39 V75 H33 Q29,75 29,71Z'),
    path('M42,38 L48,34 L54,38 L60,34 L66,38 V71 L60,75 L54,71 L48,75 L42,71Z'),
    path('M69,34 H75 Q79,34 79,38 V71 Q79,75 75,75 H69Z'),
    line('M48,42 V67 M60,42 V67',3),
    dot(34,47,2),dot(34,62,2),dot(74,47,2),dot(74,62,2),
)

keyboard=group(
    path('M28,37 Q28,33 32,32 L42,30 V76 L32,78 Q28,79 28,75Z'),
    path('M45,36 L51,32 L57,35 L63,31 L67,33 V69 L63,73 L57,70 L51,74 L45,71Z',ORANGE),
    path('M70,31 Q70,28 73,27 L78,26 Q81,25 81,29 V66 Q81,69 78,70 L73,71 Q70,72 70,68Z'),
    # Broad key groups, with only three black keys surviving the small preview.
    line('M30,43 L40,41 M30,54 L40,52 M30,65 L40,63',1.9),
    path('M29,43 L35,42 V47 L29,48Z',PURPLE,data_cutout='true'),
    path('M29,54 L35,53 V58 L29,59Z',PURPLE,data_cutout='true'),
    path('M29,65 L35,64 V69 L29,70Z',PURPLE,data_cutout='true'),
    line('M51,39 V67 M61,37 V65',2.8),
    dot(75.5,39,1.7),dot(75.5,49,1.7),dot(75.5,59,1.7),
)

open_bellows=group(
    path('M26,43 Q25,40 28,38 L34,34 Q37,32 38,36 L47,69 Q48,72 45,74 L39,78 Q36,80 35,76Z'),
    path('M39,39 L45,35 L50,38 L56,32 L61,35 L68,30 L67,67 L61,73 L55,69 L50,76 L45,72 L48,69Z',ORANGE),
    path('M71,30 Q72,27 75,28 L81,31 Q84,32 83,36 L75,69 Q74,72 71,71 L65,68 Q62,67 63,64Z'),
    line('M46,42 L51,67 M57,39 L57,65',2.8),
    line('M31,45 L33,50 M35,58 L36,63 M38,70 L39,73',2.7),
    dot(76,40),dot(73.5,50),dot(71,60),
)

concertina=group(
    # Two small polygonal ends create the identity of a concertina.
    path('M27,43 L36,34 L46,39 L49,64 L40,75 L30,70Z'),
    path('M45,41 L51,37 L56,41 L62,37 L68,41 V67 L62,71 L56,67 L51,71 L46,67Z',ORANGE),
    path('M67,36 L78,32 L85,41 L82,67 L72,76 L64,68Z'),
    line('M52,45 V63 M61,45 V63',2.8),
    dot(35,46),dot(40,50),dot(36,57),dot(41,61),
    dot(74,44),dot(79,47),dot(72.5,56),dot(77.5,59),
)

studies=[
    ('h1-ausgangspunkt','H1','Ausgangspunkt','Das bisherige Akkordeon.',PURPLE,original()),
    ('h2-pur','H2','Pur','Ruhiger, gerader und einfarbig.',PURPLE,pur),
    ('h3-klaviatur','H3','Mit Klaviatur','Deutlicher als Akkordeon lesbar.',PURPLE,keyboard),
    ('h4-aufgezogen','H4','Aufgezogen','Mehr Bewegung im geöffneten Balg.',PURPLE,open_bellows),
    ('h5-konzertina','H5','Konzertina','Kantige Enden, kompakte Folk-Anmutung.',PURPLE,concertina),
    ('h6-warmer-klang','H6','Warmer Klang','Warme Enden auf dunklerem Violett.',PLUM,original(True)),
]
studies=[(*study[:-1],normalize(study[-1])) for study in studies]

for stem,number,title,subtitle,bg,art in studies:
    svg=document(art,stem,bg)
    svg.set('width','1024');svg.set('height','1024')
    title_node=node('title');title_node.text=f'{number} · {title}';svg.insert(0,title_node)
    ET.indent(svg,space='  ')
    ET.ElementTree(svg).write(ROOT/f'{stem}.svg',encoding='utf-8',xml_declaration=True)
    svg.set('viewBox','18 18 72 72')
    temporary=ROOT/f'.{stem}-viewport.svg'
    ET.ElementTree(svg).write(temporary,encoding='utf-8')
    subprocess.run(['rsvg-convert',str(temporary),'-o',str(ROOT/f'{stem}.png')],check=True)
    temporary.unlink()
    mono=document(art,stem,bg,True)
    ET.ElementTree(mono).write(ROOT/f'{stem}-monochrome.svg',encoding='utf-8',xml_declaration=True)

sheet=node('svg',width=1800,height=1320,viewBox='0 0 1800 1320')
defs=node('defs');sheet.append(defs)
for form,outline in [('circle',node('circle',cx=54,cy=54,r=36)),('rounded',node('rect',x=18,y=18,width=72,height=72,rx=21.6))]:
    clip=node('clipPath',id=form);clip.append(outline);defs.append(clip)
for stem,number,title,subtitle,bg,art in studies: defs.append(mask(art,stem))
sheet.append(node('rect',width=1800,height=1320,fill='#F4F1F5'))


def text(x,y,content,size=22,color='#2D2432',weight=400):
    item=node('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,font_weight=weight,fill=color)
    item.text=content;sheet.append(item)


def icon(x,y,size,stem,bg,art,form='circle',mono=False):
    outer=node('g',transform=f'translate({x-18*size/72} {y-18*size/72}) scale({size/72})')
    body=node('g',clip_path=f'url(#{form})')
    body.append(node('rect',width=108,height=108,fill='#DED0EA' if mono else bg))
    body.append(foreground(art,stem,bg,mono,'#4E3462'))
    outer.append(body);sheet.append(outer)


text(70,68,'Rudolstadt / Android · Akkordeon-Studien',24,'#786B7D',500)
text(68,132,'Sechs Varianten für H',48,weight=600)
text(70,177,'Vom ruhigen Zeichen bis zum geöffneten Instrument · alle ohne Farbverlauf',24,'#786B7D')
for i,(stem,number,title,subtitle,bg,art) in enumerate(studies):
    x,y=70+(i%3)*574,229+(i//3)*510
    text(x,y+35,f'{number}  {title}',30,weight=600)
    text(x,y+74,subtitle,21,'#786B7D')
    icon(x+6,y+112,250,stem,bg,art)
    icon(x+325,y+112,94,stem,bg,art,'rounded')
    icon(x+325,y+249,94,stem,bg,art,mono=True)
    text(x+325,y+226,'Form',17,'#786B7D')
    text(x+325,y+363,'Systemfarbe',17,'#786B7D')
    icon(x+6,y+396,48,stem,bg,art)
    text(x+70,y+427,'48 px',18,'#786B7D')
    icon(x+177,y+386,64,stem,bg,art)
    text(x+257,y+427,'64 px',18,'#786B7D')
text(70,1290,'Editierbare Vektorentwürfe · Außenformen und Systemfarben sind simuliert.',20,'#786B7D')
ET.indent(sheet,space='  ')
ET.ElementTree(sheet).write(ROOT/'vergleich.svg',encoding='utf-8',xml_declaration=True)
subprocess.run(['rsvg-convert',str(ROOT/'vergleich.svg'),'-o',str(ROOT/'vergleich.png')],check=True)
print(f'Rendered {len(studies)} accordion studies and monochrome masks.')
