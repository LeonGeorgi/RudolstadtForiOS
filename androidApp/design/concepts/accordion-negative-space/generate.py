"""Render accordion variations designed around transparent gaps and monochrome recognition. Requires Python 3, librsvg and ImageMagick."""
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


# All dark details are real transparent cutouts in the alpha mask. The color
# artwork and the system-color version therefore share the same silhouette.


def rotate_point(center,angle,x,y):
    a=math.radians(angle);c,s=math.cos(a),math.sin(a)
    return (center[0]+c*x-s*y,center[1]+s*x+c*y)


def coord(p): return f'{p[0]:.5f},{p[1]:.5f}'


def lerp(a,b,t): return (a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)


def extend(a,b,distance):
    length=math.dist(a,b);u=((b[0]-a[0])/length,(b[1]-a[1])/length)
    return ((a[0]-u[0]*distance,a[1]-u[1]*distance),(b[0]+u[0]*distance,b[1]+u[1]*distance))


def opened(separate_folds=False,keyboard=False,angular=False):
    lc,la=(34,56),-17
    rc,ra=(74,51),14
    lt,lb=rotate_point(lc,la,6,-19),rotate_point(lc,la,6,19)
    rt,rb=rotate_point(rc,ra,-6,-19),rotate_point(rc,ra,-6,19)
    top=[];bottom=[]
    for i in range(7):
        a,b=lerp(lt,rt,i/6),lerp(lb,rb,i/6)
        offset=2.5 if i%2 else 0
        top.append((a[0],a[1]-offset));bottom.append((b[0],b[1]+offset))
    body='M'+' L'.join(coord(p) for p in top+list(reversed(bottom)))+' Z'
    if angular:
        left='M6,-22 L-2,-24 L-9,-16 V16 L-2,24 L6,22Z'
        right='M-6,-22 L2,-24 L9,-16 V16 L2,24 L-6,22Z'
    else:
        left='M6,-22 H-3 Q-6,-22 -6,-19 V19 Q-6,22 -3,22 H6Z'
        right='M-6,-22 H3 Q6,-22 6,-19 V19 Q6,22 3,22 H-6Z'
    if keyboard:
        controls=[
            path('M-6.4,-13 H2 V-8.8 H-6.4Z',PURPLE,data_cutout='true'),
            path('M-6.4,-2.1 H2 V2.1 H-6.4Z',PURPLE,data_cutout='true'),
            path('M-6.4,8.8 H2 V13 H-6.4Z',PURPLE,data_cutout='true'),
        ]
    elif angular:
        controls=[dot(-2,-11),dot(1,0),dot(-2,11)]
    else:
        controls=[line('M0,-12 V-8 M0,-2 V2 M0,8 V12',2.8)]
    left_panel=group(path(left),*controls,transform=f'translate({lc[0]} {lc[1]}) rotate({la})')
    right_panel=group(path(right),dot(0,-11),dot(0,0),dot(0,11),transform=f'translate({rc[0]} {rc[1]}) rotate({ra})')
    artwork=group(path(body,ORANGE),left_panel,right_panel)
    # Deliberate seams follow the exact shared attachment edges.
    for a,b in ((lt,lb),(rt,rb)):
        start,end=extend(a,b,1)
        artwork.append(line(f'M{coord(start)} L{coord(end)}',2.8))
    for t in (2/6,4/6):
        a,b=lerp(lt,rt,t),lerp(lb,rb,t)
        if separate_folds:
            start,end=extend(a,b,2)
        else:
            start,end=extend(a,b,-5)
        artwork.append(line(f'M{coord(start)} L{coord(end)}',3))
    return artwork


# The R is formed by disconnected key groups. It is part of the outer
# keyboard silhouette, rather than a letter printed on the casing.
r_keys=(
    'M25,79 V35 Q25,32 28,31 L36,29 Q46,27 46,39 V44 '
    'Q46,51 39,54 L47,74 L39,76 L32,58 V77Z '
    'M32,39 V49 L36,48 Q40,47 40,42 Q40,37 36,38Z'
)
r_keyboard=group(
    path('M46,37 L51,34 L57,37 L63,33 L69,35 V70 L63,74 L57,71 L51,75 L46,72Z',ORANGE),
    path('M71,33 Q71,30 74,29 L79,28 Q82,27 82,31 V67 Q82,70 79,71 L74,72 Q71,73 71,69Z'),
    path(r_keys,fill_rule='evenodd'),
    # Complete seams divide the keyboard while preserving the R silhouette.
    line('M24,45 L45,40 M24,57 L43,52 M24,69 L43,65',2.15),
    line('M51,34 V75 M63,33 V74',2.8),
    dot(76.5,40),dot(76.5,50),dot(76.5,60),
)

compact=group(
    path('M28,38 Q28,34 32,34 H39 V75 H32 Q28,75 28,71Z'),
    path('M42,38 L48,34 L54,38 L60,34 L66,38 V71 L60,75 L54,71 L48,75 L42,71Z',ORANGE),
    path('M69,34 H76 Q80,34 80,38 V71 Q80,75 76,75 H69Z'),
    line('M48,34 V75 M60,34 V75',2.8),
    dot(33.5,46,2),dot(33.5,63,2),dot(74.5,46,2),dot(74.5,63,2),
)

# Broad open-ended channels create a spare, almost cut-paper version.
wide_folds=opened(True)
for child in wide_folds:
    if child.get('stroke-width')=='3': child.set('stroke-width','4.5')
# The end controls are fewer and larger in this version.
for cap in list(wide_folds)[1:3]:
    for child in list(cap)[1:]: cap.remove(child)
    cap.extend([dot(0,-9,2.1),dot(0,9,2.1)])

studies=[
    ('k1-fugen','K1','Mit Gehäusefugen','Schmale Trennungen, geschlossene Falten.',opened()),
    ('k2-offene-falten','K2','Offene Falten','Die Falten bleiben auch einfarbig getrennt.',opened(True)),
    ('k3-klaviatur','K3','Klaviatur im Schwung','Offene Falten und eine deutliche Klaviatur.',opened(True,True)),
    ('k4-r-aus-tasten','K4','R aus Tasten','Einzelne Tasten formen zusammen das R.',r_keyboard),
    ('k5-konzertina','K5','Konzertina','Kantige Enden und ein offener Balg.',opened(True,False,True)),
    ('k6-balg-pur','K6','Balg pur','Breitere Lücken und weniger Bedienelemente.',wide_folds),
]
studies=[(*study[:-1],normalize(study[-1])) for study in studies]

for stem,number,title,subtitle,art in studies:
    svg=document(art,stem,PURPLE)
    svg.set('width','1024');svg.set('height','1024')
    label=node('title');label.text=f'{number} · {title}';svg.insert(0,label)
    ET.indent(svg,space='  ')
    ET.ElementTree(svg).write(ROOT/f'{stem}.svg',encoding='utf-8',xml_declaration=True)
    svg.set('viewBox','18 18 72 72')
    temporary=ROOT/f'.{stem}-viewport.svg'
    ET.ElementTree(svg).write(temporary,encoding='utf-8')
    subprocess.run(['rsvg-convert',str(temporary),'-o',str(ROOT/f'{stem}.png')],check=True)
    temporary.unlink()
    ET.ElementTree(document(art,stem,PURPLE,True)).write(ROOT/f'{stem}-monochrome.svg',encoding='utf-8',xml_declaration=True)

sheet=node('svg',width=1800,height=1300,viewBox='0 0 1800 1300')
defs=node('defs');sheet.append(defs)
clip=node('clipPath',id='circle');clip.append(node('circle',cx=54,cy=54,r=36));defs.append(clip)
for stem,number,title,subtitle,art in studies: defs.append(mask(art,stem))
sheet.append(node('rect',width=1800,height=1300,fill='#F4F1F5'))


def text(x,y,content,size=22,color='#2D2432',weight=400):
    item=node('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,font_weight=weight,fill=color)
    item.text=content;sheet.append(item)


def icon(x,y,size,stem,art,mono=False):
    outer=node('g',transform=f'translate({x-18*size/72} {y-18*size/72}) scale({size/72})')
    body=node('g',clip_path='url(#circle)')
    body.append(node('rect',width=108,height=108,fill='#DED0EA' if mono else PURPLE))
    body.append(foreground(art,stem,PURPLE,mono,'#4E3462'))
    outer.append(body);sheet.append(outer)


text(70,68,'Rudolstadt / Android · Form und Zwischenräume',24,'#786B7D',500)
text(68,132,'Das Akkordeon muss auch einfarbig tragen',45,weight=600)
text(70,177,'Farbe und Systemfarbe gleich groß · echte transparente Fugen und Aussparungen',23,'#786B7D')
for i,(stem,number,title,subtitle,art) in enumerate(studies):
    x,y=70+(i%3)*574,229+(i//3)*500
    text(x,y+35,f'{number}  {title}',29,weight=600)
    text(x,y+74,subtitle,20,'#786B7D')
    icon(x,y+110,214,stem,art)
    icon(x+260,y+110,214,stem,art,True)
    text(x,y+359,'Farbe',18,'#786B7D')
    text(x+260,y+359,'Systemfarbe',18,'#786B7D')
    icon(x,y+393,48,stem,art)
    icon(x+68,y+393,48,stem,art,True)
    text(x+137,y+423,'48 px',18,'#786B7D')
    icon(x+260,y+383,64,stem,art)
    icon(x+342,y+383,64,stem,art,True)
    text(x+424,y+423,'64 px',18,'#786B7D')
text(70,1270,'Vektorentwürfe · Systemfarben sind simuliert · Das eingebundene App-Icon bleibt unverändert.',20,'#786B7D')
ET.indent(sheet,space='  ')
ET.ElementTree(sheet).write(ROOT/'vergleich.svg',encoding='utf-8',xml_declaration=True)
subprocess.run(['rsvg-convert',str(ROOT/'vergleich.svg'),'-o',str(ROOT/'vergleich.png')],check=True)
print('Rendered six accordion variations with transparent seams and equal-size color/monochrome comparisons.')
