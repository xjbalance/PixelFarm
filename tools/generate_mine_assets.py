"""Extend the project's original pixel geometry palette; no external art or image service."""
from pathlib import Path
from PIL import Image, ImageDraw
import random
root=Path(__file__).resolve().parents[1]
rng=random.Random(5050)
im=Image.new('RGBA',(384,32));d=ImageDraw.Draw(im)
colors=['655b50','393b43','685b4e','9a8d72','4b6267','2c434e','365c70','899e9c','575571','32364d','666584','b0abc7']
for i,c in enumerate(colors):
 x=i*32;d.rectangle((x,0,x+31,31),fill='#'+c)
 for _ in range(12):
  a=x+rng.randrange(2,29);b=rng.randrange(2,29)
  shade=tuple(min(255,int(c[j:j+2],16)+rng.choice([-10,9])) for j in (0,2,4))
  d.rectangle((a,b,a+2,b+1),fill=shade)
 if i in (1,5,9):
  d.rectangle((x,25,x+31,31),fill='#222d38');d.line((x+2,3,x+29,3),fill='#87908c',width=2)
  d.line((x+9,7,x+5,22),fill='#454c57',width=2)
 if i==2:
  for y in (6,23):d.rectangle((x,y,x+31,y+2),fill='#bbb8a0')
  for a in (3,19):d.rectangle((x+a,2,x+a+4,29),fill='#4a413a')
 if i in (3,7,11):
  for y in range(2,32,8):d.rectangle((x,y,x+30,y+2),fill='#c0b9a1')
 if i==6:
  d.line((x+2,9,x+18,9),fill='#709eaa',width=2);d.line((x+12,23,x+29,23),fill='#496f83',width=2)
 if i==10:
  d.polygon([(x+14,8),(x+19,15),(x+14,23),(x+9,15)],fill='#aac7d1')
im.save(root/'assets/tilesets/mines.png')
