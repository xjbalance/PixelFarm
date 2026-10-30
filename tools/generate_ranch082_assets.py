"""Extend the game's native pixel pipeline with four-way animals and ranch furniture.
All drawings are integer pixels, no resampling; colour ramps match world_palette.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
from world_palette import harmonize
R=Path(__file__).resolve().parents[1]; OUT=R/'assets/livestock/ranch082';OUT.mkdir(parents=True,exist_ok=True)
D='#525c4a';CREAM='#f4ead1';HI='#fff4df';SHADE='#d4c2a0';WOOD='#b88e61';LIGHT='#e1c18d';EARTH='#634c3b';GOLD='#ddba64';TEAL='#5a9582'

def bird(species,direction,frame,action):
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im);duck=species=='duck'
 phase=[0,1,0,-1][frame];head_drop=4 if action==1 and frame in (1,2) else 0;rest=action==2
 # Single-pixel contour and left-top cream highlight; duck has longer low body.
 by=16 if rest else 13;bottom=25 if rest else 23
 d.ellipse((5,by,23,bottom),fill=D);d.ellipse((6,by,22,bottom-2),fill=CREAM);d.arc((7,by,22,bottom-2),0,100,fill=SHADE,width=2)
 if direction in (1,2):
  hx=20;hy=(12 if duck else 7)+head_drop+(2 if rest else 0)
  d.polygon([(6,by+3),(1,by-3),(3,by+8),(9,bottom-3)],fill=TEAL if not duck else SHADE)
  d.rectangle((hx-2,hy,hx+6,hy+10),fill=D);d.rectangle((hx-1,hy,hx+5,hy+8),fill=CREAM)
  d.rectangle((hx+6,hy+4,hx+10,hy+6),fill=GOLD);d.point((hx+3,hy+2),fill=D)
  d.line((hx,hy+1,hx+3,hy+1),fill=HI)
  if not duck:d.rectangle((hx-1,hy-3,hx+1,hy-1),fill='#b85f4c');d.point((hx+3,hy-2),fill='#b85f4c')
  d.arc((9,by+1,18,bottom-3),20,160,fill=SHADE,width=2)
  d.line((8,by+2,13,by+2),fill=HI)
 else:
  hy=7+head_drop+(3 if duck else 0)+(3 if rest else 0)
  d.ellipse((10,hy-1,22,hy+11),fill=D);d.ellipse((11,hy-1,21,hy+9),fill=CREAM)
  if direction==0:
   d.point((13,hy+3),fill=D);d.point((19,hy+3),fill=D);d.rectangle((14,hy+5,18,hy+7),fill=GOLD)
   d.line((7,by+4,9,by+8),fill=SHADE);d.line((21,by+4,23,by+8),fill=SHADE)
  else:
   d.rectangle((12,hy+7,20,hy+9),fill=SHADE);d.line((13,hy+2,18,hy+2),fill=HI)
  if not duck: d.rectangle((14,hy-3,18,hy-1),fill='#b85f4c')
 if not rest:
  for x,offset in [(11,phase),(21,-phase)]:
   d.line((x,23,x+offset,28),fill='#a17a43',width=1);d.line((x-2+offset,28,x+2+offset,28),fill=GOLD,width=1)
 else:d.line((11,26,23,26),fill=GOLD)
 if direction==1:im=ImageOps.mirror(im)
 return harmonize(im)

def livestock(species,direction,frame,action):
 cow=species=='cow';w,h=(48,40) if cow else (40,36)
 im=Image.new('RGBA',(w,h));d=ImageDraw.Draw(im);phase=[0,1,0,-1][frame];rest=action==2;drop=5 if action==1 and frame in (1,2) else 0
 base=h-10;top=11 if cow else 9
 d.rounded_rectangle((7,top,w-5,base),radius=5,fill=D);d.rounded_rectangle((8,top,w-6,base-2),radius=4,fill=CREAM)
 if cow:
  for b in [(14,top+1,22,top+6),(w-16,top+7,w-8,base-4)]:d.rectangle(b,fill='#805c41')
  d.line((12,top,23,top),fill=HI,width=2)
 else:
  for x,y in [(12,11),(20,8),(28,11),(12,19),(21,18),(30,19),(17,25),(26,25)]:
   d.ellipse((x-4,y-3,x+4,y+3),fill=CREAM,outline=SHADE)
   d.point((x-2,y-2),fill=HI)
 # Four anatomical directions, side head changes orientation rather than sliding feet.
 if direction in (1,2):
  hx=w-12;hy=top+4+drop
  d.rounded_rectangle((hx,hy,hx+10,hy+13),radius=2,fill=D);d.rectangle((hx+1,hy,hx+9,hy+10),fill=SHADE if cow else '#93816a')
  d.rectangle((hx+1,hy+9,hx+11,hy+13),fill='#e1a5ad' if cow else '#b5a181')
  d.rectangle((hx-3,hy+1,hx+1,hy+4),fill=WOOD);d.rectangle((hx+8,hy-2,hx+12,hy+1),fill=WOOD)
  d.point((hx+7,hy+4),fill=D);d.point((hx+9,hy+11),fill=EARTH)
  if cow:
   d.line((hx+1,hy,hx-1,hy-4),fill=HI,width=2);d.line((hx+9,hy,hx+10,hy-4),fill=HI,width=2)
  d.line((6,top+4,3,base-1),fill=EARTH,width=1);d.rectangle((2,base-2,4,base+1),fill=WOOD)
 else:
  hx=w//2-6;hy=top+5+drop
  d.ellipse((hx-2,hy-1,hx+14,hy+15),fill=D);d.rectangle((hx,hy,hx+12,hy+12),fill=SHADE if cow else '#93816a')
  d.rectangle((hx-3,hy,hx,hy+4),fill=WOOD);d.rectangle((hx+12,hy,hx+15,hy+4),fill=WOOD)
  if direction==0:
   d.rectangle((hx,hy+9,hx+12,hy+14),fill='#e1a5ad' if cow else '#b5a181');d.point((hx+2,hy+4),fill=D);d.point((hx+10,hy+4),fill=D)
  else:
   d.rectangle((hx+1,hy,hx+11,hy+7),fill=CREAM);d.line((hx+3,hy+3,hx+8,hy+3),fill=HI)
 if not rest:
  for x,off in [(12,phase),(w-12,-phase)]:
   d.rectangle((x+off,base-1,x+3+off,h-3),fill=EARTH);d.line((x+off,h-3,x+3+off,h-3),fill=D)
 else:d.rectangle((10,base+1,w-9,base+4),fill=SHADE)
 if direction==1:im=ImageOps.mirror(im)
 return harmonize(im)

for species in ['chicken','duck','cow','sheep']:
 w,h=(32,32) if species in ('chicken','duck') else ((48,40) if species=='cow' else (40,36))
 sheet=Image.new('RGBA',(w*4,h*12))
 for action in range(3):
  for direction in range(4):
   for frame in range(4):
    image=(bird if species in ('chicken','duck') else livestock)(species,direction,frame,action)
    sheet.alpha_composite(image,(frame*w,(action*4+direction)*h))
 sheet.save(OUT/f'{species}.png')

for ident in ['nest','trough','water_basin','gate','duck_egg','salted_duck_egg']:
 size=(48,40) if ident in ['nest','trough','water_basin','gate'] else (32,32)
 im=Image.new('RGBA',size);d=ImageDraw.Draw(im)
 if ident=='nest':
  d.polygon([(4,27),(10,18),(37,18),(44,27),(39,35),(9,35)],fill=EARTH)
  for y in [24,28,32]:d.line((8,y,40,y),fill=GOLD,width=2)
  for x,y in [(15,20),(24,18),(32,21)]:d.ellipse((x-4,y-5,x+4,y+6),fill=CREAM,outline=SHADE)
  d.line((11,23,37,23),fill=LIGHT)
 elif ident in ('trough','water_basin'):
  d.rectangle((5,18,42,32),fill=EARTH);d.rectangle((7,17,40,28),fill=WOOD);d.rectangle((9,19,38,25),fill=GOLD if ident=='trough' else '#72bdca')
  d.line((8,17,39,17),fill=LIGHT,width=2);d.rectangle((8,31,12,36),fill=EARTH);d.rectangle((36,31,40,36),fill=EARTH)
  if ident=='water_basin':d.line((14,20,23,20),fill='#d7f1ed');d.line((29,23,35,23),fill='#b4e6e9')
  else:
   for x in range(12,38,4):d.point((x,20+(x%3)),fill=CREAM)
 elif ident=='gate':
  for x in [3,39]:d.rectangle((x,8,x+5,37),fill=EARTH);d.rectangle((x,7,x+4,34),fill=WOOD);d.line((x+1,8,x+1,28),fill=LIGHT)
  d.rectangle((8,14,38,18),fill=WOOD);d.rectangle((8,26,38,30),fill=WOOD);d.line((9,15,37,27),fill=LIGHT,width=2);d.rectangle((34,20,37,23),fill=D)
 else:
  if ident=='salted_duck_egg':
   d.rectangle((5,9,26,27),fill=D);d.rectangle((6,10,25,26),fill='#79b7a0');d.rectangle((7,7,24,10),fill=WOOD)
   d.rectangle((8,15,24,24),fill=CREAM);d.line((8,12,8,16),fill=HI)
  d.ellipse((10,7 if ident=='duck_egg' else 14,23,27),fill=D);d.ellipse((11,6 if ident=='duck_egg' else 14,22,25),fill='#cde8d2')
  d.line((14,10 if ident=='duck_egg' else 16,14,17 if ident=='duck_egg' else 19),fill=HI,width=2)
 harmonize(im).save(OUT/f'{ident}.png')
print('Generated native 4-way / 3-action livestock atlases and six ranch objects, shared 89-colour palette.')
