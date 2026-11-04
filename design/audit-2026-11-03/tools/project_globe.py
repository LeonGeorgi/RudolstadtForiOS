import json,math,pathlib,random
root=pathlib.Path(__file__).resolve().parent
repository=root.parents[2]
palette=json.loads((root/'globe-palette.json').read_text())
data=json.loads((repository/'shared/src/commonMain/resources/world_countries.geojson').read_text())
D=1+44000000/6371000
R=237;F=R*math.sqrt(D*D-1);CX=201;CY=437
phi0=math.radians(18);lam0=math.radians(8);h=1/D

def point(ll):
 lam,phi=map(math.radians,ll[:2]);dl=lam-lam0
 return (math.cos(phi)*math.sin(dl),math.sin(phi)*math.cos(phi0)-math.cos(phi)*math.sin(phi0)*math.cos(dl),math.cos(phi)*math.cos(phi0)*math.cos(dl)+math.sin(phi)*math.sin(phi0))
def norm(p):
 n=math.sqrt(sum(x*x for x in p));return tuple(x/n for x in p)
def intersection(a,b):
 lo,hi=0.,1.;inside=a[2]>=h
 for _ in range(30):
  t=(lo+hi)/2;p=norm(tuple(x+(y-x)*t for x,y in zip(a,b)))
  if (p[2]>=h)==inside:lo=t
  else:hi=t
 return p
def projected(p):return (CX+F*p[0]/(D-p[2]),CY-F*p[1]/(D-p[2]))
def path_ring(ring):
 vertices=[point(ll) for ll in ring]
 if not any(p[2]>=h for p in vertices):return ''
 out=[];previous=vertices[-1];old_inside=previous[2]>=h
 for current in vertices:
  inside=current[2]>=h
  if inside!=old_inside:out.append((intersection(previous,current),True))
  if inside:out.append((current,False))
  previous=current;old_inside=inside
 if len(out)<3:return ''
 coords=[]
 for i,(p,cut) in enumerate(out):
  q,prior_cut=out[i-1]
  if cut and prior_cut:
   x,y=projected(q);u,v=projected(p)
   a=math.atan2(y-CY,x-CX);b=math.atan2(v-CY,u-CX);delta=(b-a+math.pi)%(2*math.pi)-math.pi
   count=max(1,int(abs(delta)*R/2))
   coords.extend((CX+R*math.cos(a+delta*j/count),CY+R*math.sin(a+delta*j/count)) for j in range(1,count))
  coords.append(projected(p))
 return 'M'+'L'.join(f'{x:.2f},{y:.2f}' for x,y in coords)+'Z'
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="402" height="874" viewBox="0 0 402 874">','<rect width="402" height="874" fill="#000000"/>']
rng=random.Random(41)
for _ in range(140):
 x=rng.uniform(0,402);y=rng.uniform(116,874)
 if (x-CX)**2+(y-CY)**2>R**2:svg.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="0.35" fill="#AAAAAA" opacity="0.5"/>')
svg.append(f'<circle cx="{CX}" cy="{CY}" r="{R}" fill="#D6E8F2"/>')
for f in data['features']:
 props=f['properties'];code=next((props[k] for k in ['ISO_A3_EH','ISO_A3','ADM0_A3'] if props.get(k) and props[k]!='-99'),'')
 geom=f['geometry'];polys=geom['coordinates'] if geom['type']=='MultiPolygon' else [geom['coordinates']]
 paths=[path_ring(ring) for poly in polys for ring in poly];path=''.join(paths)
 if path:svg.append(f'<path id="country-{code}" d="{path}" fill="{palette.get(code,"#F5F6F8")[:7]}" stroke="#9CA8B6" stroke-width="0.65" stroke-linejoin="round" fill-rule="evenodd"/>')
svg.append('</svg>')
(root/'native-camera-globe.svg').write_text('\n'.join(svg))
print(len(''.join(svg)),len(svg),D,F)
