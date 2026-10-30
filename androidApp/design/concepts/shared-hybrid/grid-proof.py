"""Show a deterministic envelope-area normalization against an Android keyline."""
from copy import deepcopy
from pathlib import Path
import json,subprocess,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parent
NS='http://www.w3.org/2000/svg';ET.register_namespace('',NS)
m=json.loads((ROOT/'grid-analysis.json').read_text())


def n(tag,**attrs):return ET.Element(f'{{{NS}}}{tag}',{k.replace('_','-'):str(v) for k,v in attrs.items()})

def text(svg,x,y,value,size=23,color='#2D2432',weight=400,anchor='start'):
    a=n('text',x=x,y=y,font_family='Helvetica Neue, Helvetica, Arial, sans-serif',font_size=size,fill=color,font_weight=weight,text_anchor=anchor);a.text=value;svg.append(a)

def image(svg,path,x,y,size):svg.append(n('image',x=x,y=y,width=size,height=size,href=str(path.relative_to(ROOT))))


def android(folder):
    svg=n('svg',width=1024,height=1024,viewBox='18 18 72 72')
    defs=n('defs');clip=n('clipPath',id='circle');clip.append(n('circle',cx=54,cy=54,r=36));defs.append(clip);svg.append(defs)
    body=n('g',clip_path='url(#circle)');body.append(n('rect',width=108,height=108,fill='#782C74'))
    body.extend(deepcopy(list(ET.parse(folder/'foreground.svg').getroot())));svg.append(body)
    path=folder/'android.svg';ET.ElementTree(svg).write(path,encoding='utf-8')
    subprocess.run(['rsvg-convert',str(path),'-o',str(folder/'android.png')],check=True)


folder=ROOT/'GridNormalized';android(folder)
svg=n('svg',width=1500,height=1250,viewBox='0 0 1500 1250')
svg.append(n('rect',width=1500,height=1250,fill='#F4F1F5'))
text(svg,65,65,'Rudolstadt / rasterbasierte Größenregel',25,'#786B7D',500)
text(svg,65,124,'Gleiche Hüllfläche statt bloß gleiche Breite',43,weight=600)
text(svg,65,172,f"Skalierung = √(1858,27 / 1625,53) = {m['scale']:.5f} · Schwerpunkt bleibt mittig".replace('.',','),23,'#786B7D')
for i,(title,area) in enumerate([('Google-Referenz · 52 × 36 dp',m['referenceArea']),('Bisher · 52,0 dp breit',m['sourceHullArea']),('Normalisiert · 55,6 dp breit',m['referenceArea'])]):
    x=65+i*490
    text(svg,x+150,230,title,24,weight=500,anchor='middle')
    if i==0:
        group=n('g',transform=f'translate({x} 275) scale({300/72}) translate(-18 -18)')
        group.append(n('circle',cx=54,cy=54,r=36,fill='#782C74'))
        group.append(n('rect',x=28,y=36,width=52,height=36,rx=4,fill='#FFF5E9'))
        svg.append(group)
    else:
        base=ROOT if i==1 else folder
        file=ROOT/'Previews/android-default.png' if i==1 else folder/'android.png'
        image(svg,file,x,275,300)
        data=json.loads((base/'measurements.json').read_text())
        points=' '.join(f"{(a-18)*300/72+x:.3f},{(b-18)*300/72+275:.3f}" for a,b in data['convexHull'])
        svg.append(n('polygon',points=points,fill='none',stroke='#36C2CD',stroke_width=1.3))
    text(svg,x+150,619,f"Hüllfläche {area:.2f} dp²".replace('.',','),22,'#786B7D',anchor='middle')
text(svg,65,685,'Die Referenzform und das normalisierte Motiv haben rechnerisch dieselbe Hüllfläche.',23,'#786B7D')
for x,label,path in [(280,'iOS · bisher',ROOT/'Previews/ios-default.png'),(930,'iOS · normalisierte Proportion',folder/'ios.png')]:
    text(svg,x+150,755,label,25,weight=500,anchor='middle')
    image(svg,path,x,785,300)
text(svg,65,1160,'Die Keyline stammt von Google. Die Übertragung ihrer Fläche auf unser Vordergrundmotiv ist eine explizite Gestaltungsregel.',20,'#786B7D')
text(svg,65,1200,'iOS: gleiche normalisierte Kontur, nativer Export. Keine von Apple vorgeschriebene Akkordeon-Motivgröße.',20,'#786B7D')
ET.indent(svg,space='  ')
file=ROOT/'grid-normalisierung.svg';ET.ElementTree(svg).write(file,encoding='utf-8',xml_declaration=True)
subprocess.run(['rsvg-convert',str(file),'-o',str(file.with_suffix('.png'))],check=True)
print('Rendered envelope-area normalization proof.')
