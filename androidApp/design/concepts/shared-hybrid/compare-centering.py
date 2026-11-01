"""Create static centering and platform size comparisons from native exports."""
from copy import deepcopy
from pathlib import Path
import json,shutil,subprocess,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parent
NS='http://www.w3.org/2000/svg'
ET.register_namespace('',NS)


def node(tag,**attrs): return ET.Element(f'{{{NS}}}{tag}',{k.replace('_','-'):str(v) for k,v in attrs.items()})

def label(svg,x,y,text,size=24,color='#2D2432',weight=400,anchor='start'):
    item=node('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,font_weight=weight,fill=color,text_anchor=anchor);item.text=text;svg.append(item)

def image(svg,path,x,y,size): svg.append(node('image',x=x,y=y,width=size,height=size,href=str(path.relative_to(ROOT))))

def save(svg,name):
    ET.indent(svg,space='  ');file=ROOT/(name+'.svg');ET.ElementTree(svg).write(file,encoding='utf-8',xml_declaration=True)
    subprocess.run(['rsvg-convert',str(file),'-o',str(file.with_suffix('.png'))],check=True)


def android(folder):
    for name,source,bg in [('android','foreground.svg','#782C74'),('mono','monochrome.svg','#DED0EA')]:
        svg=node('svg',width=1024,height=1024,viewBox='18 18 72 72')
        defs=node('defs');clip=node('clipPath',id='circle');clip.append(node('circle',cx=54,cy=54,r=36));defs.append(clip);svg.append(defs)
        body=node('g',clip_path='url(#circle)');body.append(node('rect',width=108,height=108,fill=bg))
        for child in ET.parse(folder/source).getroot():
            copied=deepcopy(child)
            if name=='mono':copied.set('fill','#4E3462')
            body.append(copied)
        svg.append(body)
        file=folder/(name+'.svg');ET.ElementTree(svg).write(file,encoding='utf-8',xml_declaration=True)
        subprocess.run(['rsvg-convert',str(file),'-o',str(folder/(name+'.png'))],check=True)


center=ROOT/'Centering';center.mkdir(exist_ok=True)
shutil.copyfile(ROOT.parent/'accordion-tree/0/android.png',center/'before-android.png')
shutil.copyfile(ROOT.parent/'accordion-tree/0/ios.png',center/'before-ios.png')
m=json.loads((ROOT/'measurements.json').read_text())
svg=node('svg',width=1440,height=1080,viewBox='0 0 1440 1080')
svg.append(node('rect',width=1440,height=1080,fill='#F4F1F5'))
label(svg,60,65,'Rudolstadt / Zentrierung des Ausgangsentwurfs 0',25,'#786B7D',500)
label(svg,60,125,'Jetzt liegt der Flächenschwerpunkt in der Mitte',43,weight=600)
label(svg,60,170,'Kreuz = Iconmitte · Punkt = Flächenschwerpunkt der gemeinsamen Vektorkontur',22,'#786B7D')
for x,title in [(250,'Vorher'),(900,'Zentriert · 52 dp breit')]:label(svg,x+150,220,title,27,weight=600,anchor='middle')
for y,mode,title in [(250,'android','Android'),(650,'ios','iOS')]:
    label(svg,60,y+160,title,26,weight=600)
    for x,after in [(250,False),(900,True)]:
        path=ROOT/'Previews'/f'{mode}-default.png' if after else center/f'before-{mode}.png'
        image(svg,path,x,y,300)
        # Mark the source-contour centroid, not the lighting-weighted pixels.
        cx=54 if after else m['before']['centroidX'];cy=54 if after else m['before']['centroidY']
        px=x+(cx-18)/72*300;py=y+(cy-18)/72*300
        svg.append(node('path',d=f'M{x+150},{y-6} V{y+306} M{x-6},{y+150} H{x+306}',stroke='#37B8C2',stroke_width=1,opacity='.7',fill='none'))
        svg.append(node('circle',cx=px,cy=py,r=4,fill='#D85451',stroke='#FFFFFF',stroke_width=1))
        caption='54,000 / 54,000 dp' if after else f"{cx:.3f} / {cy:.3f} dp".replace('.',',')
        label(svg,x+150,y+340,caption,21,'#786B7D',anchor='middle')
label(svg,60,1040,'Geometrische Zentrierung, inklusive Aussparungen; Licht, Schatten und Hintergrund zählen nicht zur Motivfläche.',20,'#786B7D')
save(svg,'zentrierung')

sizes=[('95 %',ROOT/'SizeStudies/compact'),('100 % · Ausgangsmaß',ROOT),('105 %',ROOT/'SizeStudies/large')]
for title,folder in sizes:
    if folder!=ROOT:android(folder)
svg=node('svg',width=1500,height=1330,viewBox='0 0 1500 1330')
svg.append(node('rect',width=1500,height=1330,fill='#F4F1F5'))
label(svg,65,65,'Rudolstadt / Größenvergleich des zentrierten Motivs',25,'#786B7D',500)
label(svg,65,125,'Drei Größen, dieselbe Form',47,weight=600)
label(svg,65,171,'52 dp als Raster-Ausgangspunkt · ±5 % linear · kein behauptetes Wahrnehmungsoptimum',23,'#786B7D')
for i,(title,folder) in enumerate(sizes):
    x=65+i*490
    metrics=json.loads((folder/'measurements.json').read_text())
    label(svg,x+150,230,title,27,weight=600,anchor='middle')
    label(svg,x+150,269,f"{metrics['after']['width']:.1f} × {metrics['after']['height']:.1f} dp".replace('.',','),21,'#786B7D',anchor='middle')
    a=ROOT/'Previews/android-default.png' if folder==ROOT else folder/'android.png'
    ios=ROOT/'Previews/ios-default.png' if folder==ROOT else folder/'ios.png'
    mono=ROOT/'Previews/android-themed.png' if folder==ROOT else folder/'mono.png'
    image(svg,a,x,300,300);label(svg,x+150,638,'Android',22,'#786B7D',anchor='middle')
    image(svg,ios,x,690,300);label(svg,x+150,1027,'iOS · nativer Export',22,'#786B7D',anchor='middle')
    image(svg,mono,x+20,1090,48);image(svg,ios,x+130,1082,64)
    label(svg,x+20,1174,'48 px',18,'#786B7D');label(svg,x+130,1174,'64 px',18,'#786B7D')
label(svg,65,1274,'Alle Motive sind flächenschwerpunktzentriert und liegen innerhalb des sicheren Android-Kreises mit 66 dp Durchmesser.',20,'#786B7D')
save(svg,'groessenvergleich')
print('Created centering proof and native platform size comparisons.')
