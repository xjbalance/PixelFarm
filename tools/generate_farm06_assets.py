"""Original 1:1 pixel artwork for the farm visual sample; no downloaded assets.

The terrain masks match farm_world.gd exactly. The full ground illustration is a
cached decorative layer; original TileSet cells and collision polygons stay live.
"""
from pathlib import Path
import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/farm06';OUT.mkdir(parents=True,exist_ok=True)
W,H=1536,1024
PALETTES=[
 {'name':'spring','grass':['#91b674','#8bad6f','#9abd7d'],'blade':['#6c945b','#b7cd8b','#7aa163'],'dirt':['#c7ad78','#d8bd86','#b49a6d'],'water':['#699b9a','#5a8d91','#90b8ab'],'flower':['#e7c3b4','#f3e2af','#d2dcb7'],'leaf':['#315d42','#46734b','#5f8a55','#84a163','#b3bd78']},
 {'name':'summer','grass':['#80a970','#78a16a','#8db675'],'blade':['#527a50','#a5c27c','#6d9458'],'dirt':['#c6ac76','#d7bc85','#b09869'],'water':['#588d94','#477f8a','#82afa6'],'flower':['#eadba2','#e7c3ab','#c5cd9c'],'leaf':['#2e5940','#3d6c44','#56834b','#739c57','#a3b46e']},
 {'name':'autumn','grass':['#b3b17a','#a9ac72','#bdba85'],'blade':['#8c9563','#d0c992','#a2a66e'],'dirt':['#b99e70','#ceb080','#a58e67'],'water':['#6b999a','#5a878f','#9ebbb0'],'flower':['#d9af75','#c99164','#e3cc91'],'leaf':['#665d3d','#8b7145','#b18a50','#cca461','#dfbd77']},
 {'name':'winter','grass':['#d6dfd4','#cfdacf','#dfe5d9'],'blade':['#abbdb1','#eef0e2','#bbc9bb'],'dirt':['#b2b9a5','#c6cbb8','#9aa997'],'water':['#91b7be','#7ea6b3','#b7d1cd'],'flower':['#c5cfc0','#dbe2d3','#acbfae'],'leaf':['#5d796f','#849e90','#b1c6b8','#d8e2d3','#edf0e3']},
]
TREES=[(5,8),(7,20),(9,24),(12,6),(27,8),(29,11),(41,13),(40,23),(30,26),(19,26),(4,15),(37,6),(42,27),(25,5),(3,4),(7,4),(10,3),(18,3),(31,3),(35,4),(41,5),(45,8),(45,12),(44,21),(45,29),(3,12),(10,8),(3,18),(16,3),(43,3)]

def kind(x,y):
 v=0
 if y in (13,14) or (x in (14,15) and y>5):v=3
 if 16<=x<28 and 15<=y<23:v=4
 pond=math.hypot(x-34,y-18)
 if pond<4.8:v=3
 if pond<4.1:v=5
 if pond<2.9:v=6
 return v

def terrain(p):
 rng=random.Random(607061)
 im=Image.new('RGBA',(W,H),p['grass'][0]);d=ImageDraw.Draw(im)
 # Broad low-contrast patches, rather than per-tile confetti or tile seams.
 for i in range(95):
  x=rng.randrange(-70,W);y=rng.randrange(-70,H);rx=rng.randrange(30,105);ry=rng.randrange(16,50)
  contour=[]
  for j in range(16):
   angle=j*math.tau/16;r=rng.uniform(.73,1.12)
   contour.append((round(x+math.cos(angle)*rx*r),round(y+math.sin(angle)*ry*r)))
  d.polygon(contour,fill=p['grass'][i%3])
 # A little broken grass grain, all integer pixels, mostly matching base color.
 for i in range(5400):
  x=rng.randrange(W);y=rng.randrange(H)
  if kind(x//32,y//32):continue
  d.line((x,y,x+2+(i%3),y),fill=p['grass'][(i+1)%3],width=1)
 # Original paths with small scalloped edges and visible packed-earth center.
 mask=Image.new('L',(W,H));md=ImageDraw.Draw(mask)
 for y in range(32):
  for x in range(48):
   if kind(x,y)==3:md.rectangle((x*32,y*32,x*32+31,y*32+31),fill=255)
 # Hand-cut edge strips extend only into traversable grass, never into crops/water.
 for y in range(32):
  for x in range(48):
   if kind(x,y)!=3:continue
   for dx,dy in [(0,-1),(0,1),(-1,0),(1,0)]:
    if not (0<=x+dx<48 and 0<=y+dy<32) or kind(x+dx,y+dy)!=0:continue
    for along in range(0,32,4):
     depth=2+rng.randrange(5)
     if dx==-1:rect=(x*32-depth,y*32+along,x*32,y*32+along+3)
     elif dx==1:rect=(x*32+31,y*32+along,x*32+31+depth,y*32+along+3)
     elif dy==-1:rect=(x*32+along,y*32-depth,x*32+along+3,y*32)
     else:rect=(x*32+along,y*32+31,x*32+along+3,y*32+31+depth)
     md.rectangle(rect,fill=255)
 path=Image.new('RGBA',(W,H),p['dirt'][0]);pd=ImageDraw.Draw(path)
 for i in range(3400):
  x=rng.randrange(W);y=rng.randrange(H)
  if not mask.getpixel((x,y)):continue
  color=p['dirt'][1 if i%3 else 2]
  pd.line((x,y,x+rng.randrange(2,7),y),fill=color,width=1)
 # Narrow wheel impressions, sparse and broken; no new fences or blocked roads.
 for y in range(220,1005,23):
  for x in [462,494]:pd.line((x,y,x,y+7),fill=p['dirt'][1],width=2)
 for x in range(25,1515,25):
  for y in [433,463]:pd.line((x,y,x+8,y),fill=p['dirt'][1],width=2)
 im.paste(path,(0,0),mask);d=ImageDraw.Draw(im)
 # Field margin: softened outline, interior still exactly the old 12x8 soil area.
 soil=['#b2946a','#bea274','#9f845d'] if p['name']!='winter' else ['#b6b4a0','#c1c0ad','#a4a793']
 d.rectangle((512,480,895,735),fill=soil[0])
 for i in range(720):
  x=rng.randrange(514,894);y=rng.randrange(482,734);d.line((x,y,x+2,y),fill=soil[1+i%2])
 for y in [480,735]:
  for x in range(512,896,7):d.rectangle((x,y-2,x+4,y+2),fill=soil[0])
 for x in [512,895]:
  for y in range(480,736,7):d.rectangle((x-2,y,x+2,y+4),fill=soil[0])
 # Rounded bank lips remain inside the exact blocked water cells. Thresholded
 # mask rounding changes the silhouette only; the final pixels are never blurred.
 water_mask=Image.new('L',(W,H));wm=ImageDraw.Draw(water_mask)
 for y in range(32):
  for x in range(48):
   if kind(x,y) in (5,6):wm.rectangle((x*32,y*32,x*32+31,y*32+31),fill=255)
 rounded=ImageChops.multiply(water_mask,water_mask.filter(ImageFilter.GaussianBlur(9)).point(lambda v:255 if v>=128 else 0))
 bank=rounded.filter(ImageFilter.MaxFilter(11))
 bank_color=Image.new('RGBA',(W,H),p['dirt'][1]);im.paste(bank_color,(0,0),bank)
 water=Image.new('RGBA',(W,H),p['water'][0]);wd=ImageDraw.Draw(water)
 for y in range(32):
  for x in range(48):
   k=kind(x,y)
   if k not in (5,6):continue
   left=x*32;top=y*32;wd.rectangle((left,top,left+31,top+31),fill=p['water'][0 if k==5 else 1])
 im.paste(water,(0,0),rounded);d=ImageDraw.Draw(im)
 water_edge=ImageChops.subtract(rounded,rounded.filter(ImageFilter.MinFilter(5)))
 im.paste(Image.new('RGBA',(W,H),p['water'][2]),(0,0),water_edge);d=ImageDraw.Draw(im)
 for i in range(220):
  x=rng.randrange(950,1250);y=rng.randrange(430,750)
  if kind(x//32,y//32) in (5,6):d.line((x,y,x+3+i%8,y),fill=p['water'][0 if i%4 else 2],width=1)
 # Root soil and small plants surround only actual trees, no duplicate resources.
 for index,(cx,cy) in enumerate(TREES):
  x,y=cx*32,cy*32
  root='#85996b' if p['name'] not in ('autumn','winter') else '#a9a274' if p['name']=='autumn' else '#bdcdbd'
  d.ellipse((x-25,y-4,x+29,y+11),fill=root)
  for j in range(9):
   px=x+rng.randrange(-27,29);py=y+rng.randrange(-3,12)
   d.line((px,py,px+2,py),fill=p['blade'][j%3],width=1)
 # Ground-cover clusters leave the main yard and all usable field cells clear.
 for i in range(210):
  x=rng.randrange(24,W-24);y=rng.randrange(24,H-24)
  if kind(x//32,y//32)!=0:continue
  if 275<x<985 and 280<y<510:continue
  for j in range(4+(i%4)):
   px=x+rng.randrange(-9,10);py=y+rng.randrange(-4,5);height=rng.randrange(3,8)
   d.line((px-2,py,px-3,py-height+2),fill=p['blade'][0],width=1)
   d.line((px,py,px,py-height),fill=p['blade'][1],width=1)
   d.point((px+1,py-height+1),fill=p['blade'][2])
  if i%6==0 and p['name']!='winter':
   for j in range(3):
    px=x+rng.randrange(-11,12);py=y+rng.randrange(-8,2)
    d.rectangle((px-1,py-1,px+1,py+1),fill=p['flower'][j%3]);d.point((px,py),fill='#f4e5b6')
  elif i%7==0:
   d.line((x+8,y+2,x+11,y+2),fill='#9d9e83' if p['name']!='winter' else '#bbc8bd',width=2)
 # A few reeds on existing solid shore; exact facility/rod interaction points clear.
 for cx,cy in [(31,15),(33,14),(37,15),(38,17),(37,21),(32,22)]:
  x=cx*32+8;y=cy*32+18
  for j in range(4):
   px=x+j*4;d.line((px,y,px-2,y-14-j%3),fill=p['blade'][0],width=1)
   if p['name']!='winter':d.line((px-2,y-18-j%3,px-2,y-12-j%3),fill='#9b8259',width=2)
 im.convert('RGB').save(OUT/f'ground_{p["name"]}.png')

def tree(p,variant=0):
 im=Image.new('RGBA',(80,104));d=ImageDraw.Draw(im);rng=random.Random(806+variant*29)
 d.ellipse((12,91,71,102),fill='#304f362f')
 # trunk footprint/origin matches the old 80x104 sprite and its collision exactly.
 d.polygon([(35,61),(47,61),(47,92),(56,98),(46,97),(41,93),(34,99),(25,99),(34,91)],fill='#70523b')
 d.polygon([(39,65),(44,65),(44,92),(49,95),(42,93),(38,94)],fill='#a78354')
 d.line((36,81,25,71),fill='#71563c',width=3);d.line((45,75,54,64),fill='#71563c',width=3)
 leaf=p['leaf']
 crown=[(37,19,18,16),(24,37,20,18),(55,37,19,19),(36,58,25,22),(17,59,13,12),(60,58,14,13)]
 if variant==1:crown=[(38,14,15,13),(26,30,16,17),(50,31,17,17),(23,49,20,18),(54,49,19,18),(37,62,26,17)]
 if variant==2:crown=[(29,23,19,16),(48,20,18,15),(20,44,17,20),(57,45,18,20),(37,61,27,19)]
 for x,y,rx,ry in crown:d.ellipse((x-rx,y-ry,x+rx,y+ry),fill=leaf[0])
 for x,y,rx,ry in [(26,39,20,25),(44,27,22,23),(54,47,21,23),(24,59,19,15),(44,62,23,15)]:
  d.ellipse((x-rx,y-ry,x+rx,y+ry),fill=leaf[1])
 # Broad coherent foliage masses and small grouped leaves; light falls NW.
 for x,y,rx,ry in [(26,31,16,19),(43,19,15,11),(55,40,14,13),(21,56,11,10),(42,56,14,12)]:
  d.ellipse((x-rx,y-ry,x+rx,y+ry),fill=leaf[2])
  d.ellipse((x-rx+2,y-ry+1,x+rx-4,y+2),fill=leaf[3])
 for i in range(32):
  x=rng.randrange(13,64);y=rng.randrange(14,65)
  if im.getpixel((x,y))[3]==0:continue
  color=leaf[3 if x+y>70 else 4]
  d.line((x-2,y,x+1,y),fill=color,width=1)
  if i%3==0:d.line((x-1,y-1,x+2,y-1),fill=color,width=1)
 # Organic outer silhouette reinstated by a slight thin edge on isolated clusters.
 if p['name']=='spring':
  for x,y in [(20,32),(39,16),(54,42),(31,58),(62,31)]:
   d.rectangle((x,y,x+2,y+2),fill='#ddc5ad');d.point((x+1,y+1),fill='#f4e5ba')
 if p['name']=='winter':
  for x,y,rx in [(28,22,13),(47,35,17),(22,51,11),(52,57,11)]:
   d.ellipse((x-rx,y-3,x+rx,y+3),fill=leaf[4]);d.line((x-rx+1,y+4,x+rx-1,y+4),fill=leaf[2],width=1)
 im.save(OUT/(f'tree_{p["name"]}.png' if variant==0 else f'tree_{p["name"]}_{variant}.png'))

def soils():
 for wet in [False,True]:
  im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im);rng=random.Random(603)
  base='#765642' if wet else '#aa8058';low='#624d3f' if wet else '#946c4b';high='#89674e' if wet else '#bd966a'
  d.rounded_rectangle((0,0,31,31),radius=3,fill=low);d.rectangle((2,1,29,29),fill=base)
  for y in [7,15,23]:
   d.line((4,y,27,y),fill=low,width=2);d.line((5,y+2,25,y+2),fill=high,width=1)
  for i in range(16):
   x=rng.randrange(3,29);y=rng.randrange(2,29);d.point((x,y),fill=high if i%3 else low)
  im.save(OUT/('soil_wet.png' if wet else 'soil_dry.png'))

if __name__=='__main__':
 for p in PALETTES:
  terrain(p)
  for variant in range(3):tree(p,variant)
 soils();print('Original farm sample: four seasonal ground illustrations, twelve trees, two soils')
