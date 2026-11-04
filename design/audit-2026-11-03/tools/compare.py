from PIL import Image,ImageChops,ImageEnhance,ImageDraw
import sys,pathlib,json
root=pathlib.Path.cwd()
a=Image.open(sys.argv[1]).convert('RGB'); b=Image.open(sys.argv[2]).convert('RGB')
if a.size!=b.size: raise ValueError((a.size,b.size))
name=sys.argv[3]; folder=root/('after' if len(sys.argv)>4 else 'before')
Image.blend(a,b,.5).save(folder/(name+'-overlay.png'))
diff=ImageEnhance.Contrast(ImageChops.difference(a,b)).enhance(3); diff.save(folder/(name+'-diff.png'))
w,h=402,874
out=Image.new('RGB',(w*4,h+30),'#ddd'); draw=ImageDraw.Draw(out)
for i,(img,label) in enumerate([(a,'Sketch'),(b,'Simulator'),(Image.blend(a,b,.5),'50% Overlay'),(diff,'Difference x3')]):
 out.paste(img.resize((w,h)),(i*w,30));draw.text((i*w+12,8),label,fill='black')
out.save(folder/(name+'-comparison.png'))
print(folder/(name+'-comparison.png'))
