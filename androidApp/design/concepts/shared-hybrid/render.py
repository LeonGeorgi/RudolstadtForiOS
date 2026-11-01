"""Export native Apple variants and compose a shared Android/iOS comparison.

Needs Python 3, librsvg and Apple's Icon Composer. Pass --sheet-only to reuse
existing native exports without invoking Apple's renderer again.
"""
from copy import deepcopy
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parent
PREVIEWS=ROOT/'Previews'
PREVIEWS.mkdir(exist_ok=True)
NS='http://www.w3.org/2000/svg'
ET.register_namespace('',NS)
ICTOOL='/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool'


def node(tag,**attrs):
    return ET.Element(f'{{{NS}}}{tag}',{k.replace('_','-'):str(v) for k,v in attrs.items()})


def save_render(svg,path):
    path=Path(path)
    ET.ElementTree(svg).write(path.with_suffix('.svg'),encoding='utf-8',xml_declaration=True)
    subprocess.run(['rsvg-convert',str(path.with_suffix('.svg')),'-o',str(path)],check=True)


if '--sheet-only' not in sys.argv:
    for name,mode in [('default','Default'),('dark','Dark'),('tinted','TintedDark'),('tinted-light','TintedLight'),('clear','ClearLight')]:
        command=[ICTOOL,str(ROOT/'Rudolstadt-Akkordeon.icon'),'--export-image','--output-file',str(PREVIEWS/f'ios-{name}.png'),'--platform','iOS','--rendition',mode,'--width','1024','--height','1024','--scale','1','--design-generation','26']
        if name=='tinted': command+=['--tint-color','0.78','--tint-strength','0.65']
        if name=='tinted-light': command+=['--tint-color','0.84','--tint-strength','0.35']
        subprocess.run(command,check=True)

for name,background,source in [('android-default','#782C74','foreground.svg'),('android-themed','#DED0EA','monochrome.svg')]:
    svg=node('svg',width=1024,height=1024,viewBox='18 18 72 72')
    defs=node('defs');clip=node('clipPath',id='circle')
    clip.append(node('circle',cx=54,cy=54,r=36));defs.append(clip);svg.append(defs)
    body=node('g',clip_path='url(#circle)')
    body.append(node('rect',width=108,height=108,fill=background))
    for child in ET.parse(ROOT/source).getroot():
        copied=deepcopy(child)
        if name=='android-themed':copied.set('fill','#4E3462')
        body.append(copied)
    svg.append(body)
    save_render(svg,PREVIEWS/f'{name}.png')

sheet=node('svg',width=1560,height=1270,viewBox='0 0 1560 1270')
sheet.append(node('rect',width=1560,height=1270,fill='#F4F1F5'))


def text(x,y,content,size=22,color='#2D2432',weight=400):
    item=node('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,font_weight=weight,fill=color)
    item.text=content;sheet.append(item)


def image(path,x,y,size):
    sheet.append(node('image',x=x,y=y,width=size,height=size,href=str(path.relative_to(ROOT))))


text(70,65,'Rudolstadt / gemeinsamer Icon-Entwurf',24,'#786B7D',500)
text(68,124,'Eine Form für Android und iOS',46,weight=600)
text(70,169,'K1-Balg mit K3-Klaviatur · iOS aus Apples nativem Icon-Composer-Renderer',23,'#786B7D')
views=[
    ('android-default','Android · Farbe','Flacher Vordergrund, runde Launcher-Maske'),
    ('ios-default','iOS · Standard','Zwei Materialgruppen über Violett'),
    ('ios-dark','iOS · Dunkel','Apples automatische dunkle Darstellung'),
    ('android-themed','Android · Systemfarbe','Dieselbe Form als einfarbige Maske'),
    ('ios-tinted-light','iOS · Eingefärbt','Beispiel einer hellen violetten Tönung'),
    ('ios-clear','iOS · Klar','Apples klare Darstellung, statischer Export'),
]
for i,(stem,title,description) in enumerate(views):
    x,y=70+(i%3)*500,215+(i//3)*500
    text(x,y+25,title,27,weight=600)
    text(x,y+61,description,18,'#786B7D')
    image(PREVIEWS/f'{stem}.png',x+30,y+90,300)
    image(PREVIEWS/f'{stem}.png',x+137,y+415,64)
    text(x+222,y+456,'64 px',18,'#786B7D')
text(70,1240,'Android-Systemfarbe und Launcher-Maske sind simuliert. iOS: native statische Exporte für Designgeneration 26.',18,'#786B7D')
ET.indent(sheet,space='  ')
save_render(sheet,ROOT/'vergleich.png')
print('Rendered native iOS/Android comparison and two Android preview assets.')
