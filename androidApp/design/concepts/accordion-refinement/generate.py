"""Render R-keyboard studies and a geometrically connected open accordion. Requires Python 3, librsvg and ImageMagick."""
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


# Two approaches to the keyboard: an R-shaped key group and an R formed by
# negative space in a full keyboard end panel.
bellows='M45,37 L50,34 L56,37 L62,33 L68,35 V70 L62,74 L56,71 L50,75 L45,72Z'
right='M70,33 Q70,30 73,29 L78,28 Q81,27 81,31 V67 Q81,70 78,71 L73,72 Q70,73 70,69Z'
keyboard_r=(
    'M25,79 V35 Q25,32 28,31 L36,29 Q46,27 46,39 V44 '
    'Q46,51 39,54 L47,74 L39,76 L32,58 V77Z '
    'M32,39 V49 L36,48 Q40,47 40,42 Q40,37 36,38Z'
)


def instrument(left):
    return group(path(bellows,ORANGE),path(right),left,
        line('M51,41 V67 M62,39 V65',2.7),dot(75.5,40),dot(75.5,50),dot(75.5,60))


uppercase=instrument(group(path(keyboard_r,fill_rule='evenodd'),
    line('M26,44 L31,43 M26,64 L31,63',1.45)))
keyboard_panel='M25,37 Q25,34 28,33 L40,30 Q44,29 44,33 V74 Q44,77 41,78 L29,80 Q25,81 25,77Z'
negative_r=(
    'M29,70 V40 L34,39 Q40,38 40,46 V49 Q40,53 36,55 '
    'L41,68 L36,69 L33,58 V69Z '
    'M33,44 V51 L35,50 Q36.5,50 36.5,47 Q36.5,43 35,44Z'
)
inlaid=instrument(group(path(keyboard_panel),
    path(negative_r,PURPLE,data_cutout='true',fill_rule='evenodd')))


# H4 is rebuilt in the local coordinate system of each end panel. The bellows
# connects to their exact inner edges. All buttons and slots use that same frame.
def rotate_point(center, angle, x, y):
    radians=math.radians(angle)
    c,s=math.cos(radians),math.sin(radians)
    return (center[0]+c*x-s*y,center[1]+s*x+c*y)


def coord(point):
    return f'{point[0]:.5f},{point[1]:.5f}'


left_center,left_angle=(34,56),-17
right_center,right_angle=(74,51),14
lt=rotate_point(left_center,left_angle,6,-19)
lb=rotate_point(left_center,left_angle,6,19)
rt=rotate_point(right_center,right_angle,-6,-19)
rb=rotate_point(right_center,right_angle,-6,19)


def interpolate(a,b,t):
    return (a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)


# Top and bottom fold peaks share the same transverse positions. They are
# derived from their attachment edges, rather than placed independently.
top=[];bottom=[]
for index in range(7):
    t=index/6
    a=interpolate(lt,rt,t);b=interpolate(lb,rb,t)
    offset=2.5 if index%2 else 0
    top.append((a[0],a[1]-offset))
    bottom.append((b[0],b[1]+offset))
body='M'+' L'.join(coord(p) for p in top+list(reversed(bottom)))+' Z'
folds=[]
for t in (2/6,4/6):
    a,b=interpolate(lt,rt,t),interpolate(lb,rb,t)
    # Equal end clearance along the actual fold direction.
    length=math.dist(a,b);ux,uy=(b[0]-a[0])/length,(b[1]-a[1])/length
    start=(a[0]+ux*5,a[1]+uy*5)
    end=(b[0]-ux*5,b[1]-uy*5)
    folds.append(line(f'M{coord(start)} L{coord(end)}',2.6))

left_outline='M6,-22 H-3 Q-6,-22 -6,-19 V19 Q-6,22 -3,22 H6Z'
right_outline='M-6,-22 H3 Q6,-22 6,-19 V19 Q6,22 3,22 H-6Z'
left_panel=group(path(left_outline),line('M0,-12 V-8 M0,-2 V2 M0,8 V12',2.8),
    transform=f'translate({left_center[0]} {left_center[1]}) rotate({left_angle})')
right_panel=group(path(right_outline),dot(0,-11),dot(0,0),dot(0,11),
    transform=f'translate({right_center[0]} {right_center[1]}) rotate({right_angle})')
opened=group(path(body,ORANGE),left_panel,right_panel,*folds)

studies=[
    ('h3a-tastatur-r','H3a','R als Klaviatur','Die Tastenseite bildet ein großes R.',PURPLE,normalize(uppercase)),
    ('h3b-tastenschnitt','H3b','R im Tastenschnitt','Das R steckt in den dunklen Tasten.',PURPLE,normalize(inlaid)),
    ('h4a-sauber-geoeffnet','H4a','Geöffnet, überarbeitet','Gemeinsame Anschlüsse, gleichmäßige Details.',PURPLE,normalize(opened)),
]

for stem,number,title,subtitle,bg,art in studies:
    svg=document(art,stem,bg)
    svg.set('width','1024');svg.set('height','1024')
    label=node('title');label.text=f'{number} · {title}';svg.insert(0,label)
    ET.indent(svg,space='  ')
    ET.ElementTree(svg).write(ROOT/f'{stem}.svg',encoding='utf-8',xml_declaration=True)
    svg.set('viewBox','18 18 72 72')
    temporary=ROOT/f'.{stem}-viewport.svg'
    ET.ElementTree(svg).write(temporary,encoding='utf-8')
    subprocess.run(['rsvg-convert',str(temporary),'-o',str(ROOT/f'{stem}.png')],check=True)
    temporary.unlink()
    mono=document(art,stem,bg,True)
    ET.ElementTree(mono).write(ROOT/f'{stem}-monochrome.svg',encoding='utf-8',xml_declaration=True)

sheet=node('svg',width=1800,height=840,viewBox='0 0 1800 840')
defs=node('defs');sheet.append(defs)
for form,outline in [('circle',node('circle',cx=54,cy=54,r=36)),('rounded',node('rect',x=18,y=18,width=72,height=72,rx=21.6))]:
    clip=node('clipPath',id=form);clip.append(outline);defs.append(clip)
for stem,number,title,subtitle,bg,art in studies: defs.append(mask(art,stem))
sheet.append(node('rect',width=1800,height=840,fill='#F4F1F5'))


def text(x,y,content,size=22,color='#2D2432',weight=400):
    item=node('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,font_weight=weight,fill=color)
    item.text=content;sheet.append(item)


def icon(x,y,size,stem,bg,art,form='circle',mono=False):
    outer=node('g',transform=f'translate({x-18*size/72} {y-18*size/72}) scale({size/72})')
    body=node('g',clip_path=f'url(#{form})')
    body.append(node('rect',width=108,height=108,fill='#DED0EA' if mono else bg))
    body.append(foreground(art,stem,bg,mono,'#4E3462'))
    outer.append(body);sheet.append(outer)


text(70,68,'Rudolstadt / Android · H3 und H4',24,'#786B7D',500)
text(68,132,'Tasten, Buchstaben und saubere Falten',46,weight=600)
text(70,177,'Zwei Ansätze für das R · die geöffnete Form mit neu aufgebauter Geometrie',24,'#786B7D')
for i,(stem,number,title,subtitle,bg,art) in enumerate(studies):
    x,y=70+i*574,229
    text(x,y+35,f'{number}  {title}',29,weight=600)
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
text(70,800,'Editierbare Vektorentwürfe · Außenformen und Systemfarben sind simuliert.',20,'#786B7D')
ET.indent(sheet,space='  ')
ET.ElementTree(sheet).write(ROOT/'vergleich.svg',encoding='utf-8',xml_declaration=True)
subprocess.run(['rsvg-convert',str(ROOT/'vergleich.svg'),'-o',str(ROOT/'vergleich.png')],check=True)

# A larger before/after view makes the cleaned connections inspectable.
detail=node('svg',width=1280,height=700,viewBox='0 0 1280 700')
detail.append(node('rect',width=1280,height=700,fill='#F4F1F5'))
for x,title in [(80,'H4 · bisher'),(720,'H4a · überarbeitet')]:
    item=node('text',x=x,y=65,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=29,font_weight=600,fill='#2D2432');item.text=title;detail.append(item)
old=ET.parse(ROOT.parent/'accordion-studies/h4-aufgezogen.svg').getroot()
old.set('x','70');old.set('y','110');old.set('width','500');old.set('height','500');old.set('viewBox','18 18 72 72');detail.append(old)
new=document(studies[2][-1],'detail-refined',PURPLE)
new.set('x','710');new.set('y','110');new.set('width','500');new.set('height','500');new.set('viewBox','18 18 72 72');detail.append(new)
for x,caption in [(80,'Freihändig gesetzte Teile und Details'),(720,'Aus gemeinsamen Kanten konstruierte Form')]:
    item=node('text',x=x,y=660,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=22,fill='#786B7D');item.text=caption;detail.append(item)
ET.ElementTree(detail).write(ROOT/'h4-details.svg',encoding='utf-8',xml_declaration=True)
subprocess.run(['rsvg-convert',str(ROOT/'h4-details.svg'),'-o',str(ROOT/'h4-details.png')],check=True)
print('Rendered two R-keyboard studies, refined H4 and before/after detail.')
