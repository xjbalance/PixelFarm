"""Original 32px forest, sealed-waterworks and temple tiles + exploration icons."""
from pathlib import Path
from PIL import Image, ImageDraw
import random
R=Path(__file__).resolve().parents[1];D=R/'assets/exploration';D.mkdir(parents=True,exist_ok=True)
themes={'forest':('#879273','#4b6655','#647b64','#77a6a2'),'lake':('#8e9d93','#4c6767','#6f8881','#638f9d'),'temple':('#a69a76','#626c65','#8b8969','#6c8b9a')}
for theme,(floor,wall,edge,water) in themes.items():
 image=Image.new('RGBA',(256,32));rng=random.Random(70704+len(theme))
 for tile in range(8):
  d=ImageDraw.Draw(image);x=tile*32
  base=wall if tile in [1,4] else water if tile==2 else floor
  d.rectangle((x,0,x+31,31),fill=base)
  if tile==2:
   for i in range(8):
    px=x+rng.randrange(2,26);py=rng.randrange(3,29);d.line((px,py,px+5,py),fill='#a8c3ba',width=1)
  elif tile==1:
   if theme=='forest':
    d.rectangle((x+13,4,x+19,30),fill='#6c634b')
    for px,py in [(7,7),(23,8),(15,2),(8,20),(25,22)]:
     d.rectangle((x+px-6,max(0,py-5),x+min(31,px+6),min(31,py+5)),fill=edge)
    d.line((x+15,12,x+15,28),fill='#8a7956',width=2)
   else:
    d.rectangle((x+2,2,x+29,13),fill=edge);d.rectangle((x+2,17,x+15,29),fill=edge);d.rectangle((x+19,17,x+29,29),fill=edge)
    d.line((x+4,4,x+25,4),fill='#a2ada0',width=1)
  elif tile==4:
   if theme=='forest':
    for px in [5,14,24]:
     d.line((x+px,31,x+px+3,2),fill='#7b7050',width=4)
     for py in [6,17,25]:d.rectangle((x+px-3,py,x+px+5,py+4),fill='#899e6d')
   else:
    d.rectangle((x+3,2,x+28,30),fill=edge)
    for px in [8,16,24]:d.line((x+px,3,x+px,29),fill='#b3b79b',width=3)
    d.rectangle((x+12,11,x+20,20),fill='#c3b37d')
  elif tile in [3,5,6]:
   tone='#b2a276' if theme=='forest' else '#b0b9a6' if theme=='lake' else '#beb085'
   d.rectangle((x+1,2,x+30,29),fill=tone)
   for py in [3,12,22]:d.line((x+3,py,x+28,py),fill=edge,width=1)
   if theme=='temple':d.polygon([(x+16,7),(x+23,16),(x+16,25),(x+9,16)],outline='#d4c18b')
  else:
   for i in range(18):
    px=x+rng.randrange(1,30);py=rng.randrange(1,30)
    d.point((px,py),fill=edge)
   if theme in ['lake','temple']:
    d.line((x,0,x+31,0),fill=edge,width=1);d.line((x+16,0,x+16,31),fill=edge,width=1)
 image.save(D/f'{theme}_tiles.png')
for item in ['forest_herb','rare_fiber','ancient_token','forest_seal','tide_seal','star_seal']:
 image=Image.new('RGBA',(32,32));d=ImageDraw.Draw(image)
 if item=='forest_herb':
  for px,py in [(10,10),(20,6),(23,17),(11,21)]:
   d.line((16,29,px,py),fill='#5d7853',width=2);d.polygon([(px-5,py),(px,py-4),(px+6,py),(px,py+3)],fill='#9ebc7c')
 elif item=='rare_fiber':
  for x in [8,12,16,20,24]:d.line((x+3,5,x-2,27),fill='#c3c9a4',width=2)
  d.rectangle((7,14,24,18),fill='#887858')
 elif item=='ancient_token':
  d.polygon([(8,4),(24,5),(28,21),(21,28),(6,25),(3,12)],fill='#a9b39c',outline='#657c72')
  d.line((8,11,23,11),fill='#d7c48f',width=2);d.line((7,17,23,20),fill='#6f9997',width=2)
 else:
  color={'forest_seal':'#9daf7d','tide_seal':'#8cb7b0','star_seal':'#b3a8cc'}[item]
  d.rectangle((5,5,27,28),fill='#6e7660');d.rectangle((7,3,25,25),fill=color)
  if item=='forest_seal':
   d.line((16,7,16,23),fill='#edf0c6',width=2)
   for y in [9,15,21]:d.line((10,y,16,y+3),fill='#edf0c6',width=2);d.line((16,y+3,22,y),fill='#edf0c6',width=2)
  elif item=='tide_seal':
   for y in [10,16,22]:d.line((9,y,13,y-2,18,y+2,23,y),fill='#dce9cb',width=2)
  else:d.polygon([(16,7),(19,13),(25,14),(20,18),(21,24),(16,21),(11,24),(12,18),(7,14),(13,13)],fill='#e8dfb7')
 image.save(D/f'{item}.png')
print('Generated 3 original terrain atlases and 6 exploration icons.')
