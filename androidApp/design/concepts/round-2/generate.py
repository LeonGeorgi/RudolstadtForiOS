"""Render round two of the Android icon studies. Needs Python 3 and librsvg."""
from copy import deepcopy
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
PURPLE = '#782C74'
CREAM = '#FFF5E9'
COPPER = '#F1B779'


def node(tag, **attrs):
    return ET.Element(f'{{{NS}}}{tag}', {key.replace('_', '-'):str(value) for key,value in attrs.items()})


def shape(d, color=CREAM, **attrs):
    return node('path', d=d, fill=color, **attrs)


def line(d, color=CREAM, width=5, **attrs):
    return shape(d, 'none', stroke=color, stroke_width=width, stroke_linecap='round', stroke_linejoin='round', **attrs)


def dot(x,y,r,color=CREAM, **attrs):
    return node('circle', cx=x, cy=y, r=r, fill=color, **attrs)


def group(*children, **attrs):
    result = node('g', **attrs)
    result.extend(children)
    return result


def inset(*children, scale=.91, **attrs):
    return group(*children, transform=f'translate(54 54) scale({scale}) translate(-54 -54)', **attrs)


original = ET.parse(ROOT.parent.parent / 'launcher-icon.svg').getroot().find(f'{{{NS}}}path').get('d')
contours = re.findall(r'M[^M]*', original)
assert len(contours)==14
# First seven contours form "rudol"; all remaining contours form "stadt".
wordmark = group(shape(original, '#FFFFFF', fill_rule='evenodd'))
two_tone = group(
    shape(' '.join(contours[:7]), CREAM, fill_rule='evenodd'),
    shape(' '.join(contours[7:]), COPPER, fill_rule='evenodd'),
)

accordion = inset(
    # The diagonals echo the upward sloping baseline of the original wordmark.
    shape('M29,38 Q29,35 32,35 L38,33 Q41,32 41,36 V71 Q41,74 38,75 L32,77 Q29,78 29,74Z'),
    shape('M42,39 L47,36 L52,38 L57,34 L62,36 L67,33 V69 L62,72 L57,70 L52,74 L47,72 L42,75Z', COPPER),
    shape('M68,33 Q68,30 71,29 L77,27 Q80,26 80,30 V66 Q80,69 77,70 L71,72 Q68,73 68,69Z'),
    line('M47,40 V68 M57,38 V66', PURPLE, 2.8, data_cutout='true'),
    line('M34,43 V47 M34,55 V59 M34,67 V70', PURPLE, 3, data_cutout='true'),
    dot(74,39,1.8,PURPLE,data_cutout='true'),
    dot(74,49,1.8,PURPLE,data_cutout='true'),
    dot(74,59,1.8,PURPLE,data_cutout='true'),
    scale=.88,
)

dance = inset(
    dot(41,37,5.2),
    dot(66,36,5.2,COPPER),
    line('M42,49 L47,59 L43,68 L32,74',CREAM,7.2),
    line('M47,59 L52,72 L47,79',CREAM,7.2),
    line('M42,49 L33,49 L28,41',CREAM,6),
    line('M42,49 L50,38 L56,29',CREAM,6),
    line('M65,48 L60,58 L67,68 L78,67',COPPER,7.2),
    line('M60,58 L59,72 L66,79',COPPER,7.2),
    line('M65,48 L75,47 L81,40',COPPER,6),
    line('M65,48 L60,37 L56,29',COPPER,6),
    scale=.91,
)

programme = inset(
    shape('M33,31 Q33,27 37,27 H62 L76,41 V76 Q76,81 71,81 H37 Q33,81 33,77Z'),
    shape('M62,27 V38 Q62,41 65,41 H76Z',COPPER),
    line('M62,28 V38 Q62,41 65,41 H75',PURPLE,2.2,data_cutout='true'),
    # The note and schedule line are transparent cutouts in monochrome as well.
    shape('M53,48 L65,44 V52 L57,55 V65 C57,72 44,74 44,67 C44,62 50,60 53,61Z',PURPLE,data_cutout='true'),
    line('M42,75 H60',PURPLE,3,data_cutout='true'),
    scale=.92,
)

concepts = [
    ('a-original-pur','A','Original pur','Der vollständige Schriftzug als Bezugspunkt.',PURPLE,wordmark),
    ('g-original-zweiklang','G','Original zweifarbig','Der ganze Name, mit einem warmen Akzent.','#492B55',two_tone),
    ('h-akkordeon','H','Akkordeon','Ein Musikinstrument mit eigener Silhouette.',PURPLE,accordion),
    ('i-tanzpaar','I','Tanzpaar','Zwei Menschen, gemeinsam in Bewegung.',PURPLE,dance),
    ('j-programmklang','J','Programmklang','Programmblatt und Musik in einem Zeichen.',PURPLE,programme),
]


def paint(art, background, foreground=None):
    output = deepcopy(art)
    for item in output.iter():
        is_cutout = item.attrib.pop('data-cutout',None)=='true'
        for attr in ('fill','stroke'):
            if item.get(attr) and item.get(attr)!='none':
                if is_cutout:
                    item.set(attr,background)
                elif foreground:
                    item.set(attr,foreground)
    return output


def symbol_defs(art, prefix, bg, mono=False):
    defs = node('defs')
    # A true alpha mask: cutouts stay transparent in the exported foregrounds.
    mask = node('mask',id=f'{prefix}-mask',maskUnits='userSpaceOnUse',x=0,y=0,width=108,height=108,style='mask-type:luminance')
    mask.append(paint(art,'#000000','#FFFFFF'))
    defs.append(mask)
    return defs


def masked_art(art,prefix,bg,mono=False,fg='#FFFFFF'):
    if mono:
        return node('rect',width=108,height=108,fill=fg,mask=f'url(#{prefix}-mask)')
    # Mask removes the coloured placeholders used for the cutouts.
    return group(paint(art,bg),mask=f'url(#{prefix}-mask)')


for stem,letter,title,subtitle,bg,art in concepts:
    svg = node('svg',width=1024,height=1024,viewBox='0 0 108 108')
    title_node=node('title');title_node.text=title;svg.append(title_node)
    svg.append(symbol_defs(art,stem,bg))
    svg.append(node('rect',id='background',width=108,height=108,fill=bg))
    svg.append(group(masked_art(art,stem,bg),id='artwork'))
    ET.indent(svg,space='  ')
    ET.ElementTree(svg).write(ROOT/f'{stem}.svg',encoding='utf-8',xml_declaration=True)
    svg.set('viewBox','18 18 72 72')
    temp=ROOT/f'.{stem}-viewport.svg'
    ET.ElementTree(svg).write(temp,encoding='utf-8',xml_declaration=True)
    subprocess.run(['rsvg-convert',str(temp),'-o',str(ROOT/f'{stem}.png')],check=True)
    temp.unlink()
    mono=node('svg',width=432,height=432,viewBox='0 0 108 108')
    mono.append(symbol_defs(art,stem,bg))
    mono.append(masked_art(art,stem,bg,mono=True))
    ET.ElementTree(mono).write(ROOT/f'{stem}-monochrome.svg',encoding='utf-8',xml_declaration=True)

sheet=node('svg',width=1800,height=1320,viewBox='0 0 1800 1320')
defs=node('defs');sheet.append(defs)
for name,maskshape in (
    ('circle',node('circle',cx=54,cy=54,r=36)),
    ('rounded',node('rect',x=18,y=18,width=72,height=72,rx=21.6)),
):
    clip=node('clipPath',id=name);clip.append(maskshape);defs.append(clip)
for stem,letter,title,subtitle,bg,art in concepts:
    defs.extend(symbol_defs(art,stem,bg))
sheet.append(node('rect',width=1800,height=1320,fill='#F4F1F5'))


def text(x,y,content,size=22,color='#2D2432',weight=400):
    item=node('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,font_weight=weight,fill=color)
    item.text=content;sheet.append(item)


def icon(x,y,size,stem,bg,art,form='circle',mono=False):
    outer=node('g',transform=f'translate({x-18*size/72} {y-18*size/72}) scale({size/72})')
    content=node('g',clip_path=f'url(#{form})')
    content.append(node('rect',width=108,height=108,fill='#DED0EA' if mono else bg))
    content.append(masked_art(art,stem,bg,mono,fg='#4E3462'))
    outer.append(content);sheet.append(outer)


text(70,68,'Rudolstadt / Android · Runde 2',24,'#786B7D',500)
text(68,132,'Festival statt Kürzel',48,'#2D2432',600)
text(70,177,'Der ganze Name oder ein Bildzeichen für Musik, Tanz und Programm.',24,'#786B7D')
for i,(stem,letter,title,subtitle,bg,art) in enumerate(concepts):
    col,row=i%3,i//3
    x,y=70+col*574,229+row*510
    text(x,y+35,f'{letter}  {title}',30,weight=600)
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
# The sixth slot gives a short decision aid without another weak design variant.
text(1218,774,'Die Richtungen',30,weight=600)
for dy,label in [(824,'A / G  ·  Identität durch den Namen'),(874,'H  ·  Musik und Folk'),(924,'I  ·  Begegnung und Tanz'),(974,'J  ·  Das Festivalprogramm')]:
    text(1218,dy,label,23,'#786B7D')
text(1218,1075,'Alle Entwürfe ohne Farbverlauf.',21,'#786B7D')
text(1218,1110,'Form und Systemfarbe sind simuliert.',21,'#786B7D')
text(70,1290,'Editierbare Vektorentwürfe · Das eingebundene App-Icon bleibt unverändert.',20,'#786B7D')
ET.indent(sheet,space='  ')
ET.ElementTree(sheet).write(ROOT/'vergleich.svg',encoding='utf-8',xml_declaration=True)
subprocess.run(['rsvg-convert',str(ROOT/'vergleich.svg'),'-o',str(ROOT/'vergleich.png')],check=True)
print(f'Rendered {len(concepts)} concepts, monochrome masks and comparison sheet.')
