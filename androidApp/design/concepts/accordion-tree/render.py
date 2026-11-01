"""Render the seven nodes of the accordion decision tree.

Requires Python 3, librsvg and Apple's Icon Composer. --reuse-native skips
native exports when rebuilding the overview from existing images.
"""
from copy import deepcopy
from pathlib import Path
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parent
NS='http://www.w3.org/2000/svg'
ET.register_namespace('',NS)
ICTOOL='/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool'
variants=json.loads((ROOT/'variants.json').read_text())


def node(tag,**attrs):
    return ET.Element(f'{{{NS}}}{tag}',{k.replace('_','-'):str(v) for k,v in attrs.items()})


def render(svg,path):
    path=Path(path)
    ET.ElementTree(svg).write(path.with_suffix('.svg'),encoding='utf-8',xml_declaration=True)
    subprocess.run(['rsvg-convert',str(path.with_suffix('.svg')),'-o',str(path)],check=True)


for item in variants:
    key=item['id'];folder=ROOT/key
    if '--reuse-native' not in sys.argv:
        for size,suffix in [(1024,'ios'),(192,'ios-thumb')]:
            result=subprocess.run([ICTOOL,str(folder/f'Akkordeon-{key}.icon'),'--export-image','--output-file',str(folder/f'{suffix}.png'),'--platform','iOS','--rendition','Default','--width',str(size),'--height',str(size),'--scale','1','--design-generation','26'],capture_output=True,text=True)
            if result.returncode:raise RuntimeError(f'{key}: {result.stdout} {result.stderr}')
    for mode,source,bg in [('android','foreground.svg','#782C74'),('mono','monochrome.svg','#DED0EA')]:
        for size,suffix in [(1024,mode),(192,mode+'-thumb')]:
            svg=node('svg',width=size,height=size,viewBox='18 18 72 72')
            defs=node('defs');clip=node('clipPath',id='circle')
            clip.append(node('circle',cx=54,cy=54,r=36));defs.append(clip);svg.append(defs)
            body=node('g',clip_path='url(#circle)')
            body.append(node('rect',width=108,height=108,fill=bg))
            for child in ET.parse(folder/source).getroot():
                copied=deepcopy(child)
                if mode=='mono':copied.set('fill','#4E3462')
                body.append(copied)
            svg.append(body);render(svg,folder/f'{suffix}.png')
    print(f"Rendered {key}: {item['title']}",flush=True)

# A static tree remains available alongside the interactive comparison.
sheet=node('svg',width=1800,height=1530,viewBox='0 0 1800 1530')
sheet.append(node('rect',width=1800,height=1530,fill='#F4F1F5'))


def text(x,y,content,size=24,color='#2D2432',weight=400,anchor='start'):
    item=node('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,font_weight=weight,fill=color,text_anchor=anchor)
    item.text=content;sheet.append(item)


def image(key,mode,x,y,size):
    sheet.append(node('image',x=x,y=y,width=size,height=size,href=f'{key}/{mode}.png'))


def edge(x1,y1,x2,y2):
    middle=(y1+y2)/2
    sheet.append(node('path',d=f'M{x1},{y1} V{middle} H{x2} V{y2}',fill='none',stroke='#C9C1CD',stroke_width=2))


text(70,68,'Rudolstadt / Akkordeon · Entscheidungsbaum',25,'#786B7D',500)
text(70,132,'Erst die Haltung, dann die Details',48,weight=600)
text(70,179,'Farben und iOS-Material bleiben gleich. Jede Abzweigung verändert gezielt eine Richtung.',23,'#786B7D')
positions={'0':(900,232),'A':(450,620),'B':(1350,620),'A1':(225,1055),'A2':(675,1055),'B1':(1125,1055),'B2':(1575,1055)}
for parent,child in [('0','A'),('0','B'),('A','A1'),('A','A2'),('B','B1'),('B','B2')]:
    px,py=positions[parent];cx,cy=positions[child]
    edge(px,py+316,cx,cy-42)
for item in variants:
    key=item['id'];x,y=positions[key]
    text(x,y,f"{key} · {item['title']}",27,weight=500,anchor='middle')
    image(key,'android',x-152,y+26,142)
    image(key,'ios',x+10,y+26,142)
    image(key,'mono',x-32,y+200,64)
    text(x-80,y+190,'Android',18,'#786B7D',anchor='middle')
    text(x+80,y+190,'iOS',18,'#786B7D',anchor='middle')
    text(x,y+295,'Systemfarbe · 64 px',17,'#786B7D',anchor='middle')
text(70,1500,'iOS: native Icon-Composer-Exporte · Android-Maske und Systemfarben sind simuliert.',20,'#786B7D')
ET.indent(sheet,space='  ')
render(sheet,ROOT/'entscheidungsbaum.png')
print('Rendered the static decision tree.',flush=True)
