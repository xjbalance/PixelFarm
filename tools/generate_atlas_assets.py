"""Original parchment cartography, drawn as clustered pixel silhouettes, not TileMap screenshots.
All coordinates below describe actual region footprints; POIs/player/progress are live Godot overlays.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import math,random
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps';OUT.mkdir(exist_ok=True)
S=(512,320)
PAPER='#ead8ae';EDGE='#b68a59';INK='#72553b';GRASS='#b4bf83';DARK='#7d9567';LEAF='#62806a';LIGHT='#d0d19a';WATER='#86b5ad';RIVER='#719e9a';PATH='#c7a878'
def paper(seed):
 im=Image.new('RGB',S,PAPER);d=ImageDraw.Draw(im);r=random.Random(seed)
 d.rounded_rectangle((7,6,504,313),radius=5,fill='#d8be8c',outline=INK,width=2)
 d.rounded_rectangle((10,9,501,310),radius=4,fill=PAPER,outline='#f7e8c7')
 for i in range(420):
  x=r.randrange(13,499);y=r.randrange(12,308);d.line((x,y,x+r.randrange(1,5),y),fill=r.choice(['#e3cca0','#efdfbc','#e8d4aa']))
 for y in [15,303]:
  d.line((20,y,491,y),fill='#bb9665');d.line((20,y+1,491,y+1),fill='#f6e7c6')
 for x in [19,491]:
  d.line((x,19,x,299),fill='#bb9665')
 # Original compass and corner rule flourishes, no baked Chinese labels.
 for x,y in [(25,24),(486,24),(25,295),(486,295)]:
  d.line((x-4,y,x+4,y),fill=INK);d.line((x,y-4,x,y+4),fill=INK)
 return im,d

def terrain(d,box,fill=GRASS):
 x,y,w,h=box;pts=[(x,y+11),(x+18,y+3),(x+w*.38,y+6),(x+w*.65,y),(x+w-8,y+9),(x+w,y+h*.33),(x+w-3,y+h*.72),(x+w-21,y+h),(x+w*.60,y+h-4),(x+w*.24,y+h),(x+4,y+h-14),(x,y+h*.50)]
 d.polygon(pts,fill=fill);d.line(pts+[pts[0]],fill='#9ba578',width=2)

def road(d,pts,width=8):
 d.line(pts,fill='#a68e63',width=width+3,joint='curve');d.line(pts,fill=PATH,width=width,joint='curve');d.line([(x,y-1) for x,y in pts],fill='#dbc398',width=max(2,width-4),joint='curve')
def water(d,pts,width=13):
 d.line(pts,fill='#a7b58c',width=width+10,joint='curve');d.line(pts,fill='#577e78',width=width+3,joint='curve');d.line(pts,fill=WATER,width=width,joint='curve');d.line([(x-1,y) for x,y in pts],fill='#b8d2ba',width=2,joint='curve')
def tree(d,x,y,s=1):
 x=int(x);y=int(y);s=max(1,s)
 d.ellipse((x-7*s,y+3*s,x+9*s,y+6*s),fill='#9ba778')
 d.rectangle((x-1,y,x+1,y+6*s),fill=INK)
 d.polygon([(x-8*s,y),(x-10*s,y-5*s),(x-6*s,y-11*s),(x-2*s,y-13*s),(x+3*s,y-14*s),(x+8*s,y-9*s),(x+10*s,y-3*s),(x+6*s,y+2*s),(x-4*s,y+2*s)],fill='#566d54')
 d.ellipse((x-7*s,y-12*s,x+7*s,y-1*s),fill=LEAF);d.ellipse((x-6*s,y-12*s,x+1*s,y-5*s),fill='#8eaa78');d.line((x-4*s,y-11*s,x,y-12*s),fill='#b8c28a',width=1)
def cluster(d,box,count=25,seed=5):
 r=random.Random(seed);x,y,w,h=box
 for i in range(count): tree(d,r.randrange(int(x),int(x+w)),r.randrange(int(y),int(y+h)))
def house(d,x,y,scale=1,level=1):
 x=int(x);y=int(y);w=int(23*scale);h=int(18*scale)
 d.rectangle((x-w//2,y-h//2,x+w//2,y+h//2),fill='#765a3e');d.rectangle((x-w//2+2,y-h//2+2,x+w//2-2,y+h//2-1),fill='#e4cea0')
 d.polygon([(x-w//2-3,y-h//2+2),(x,y-h//2-11),(x+w//2+3,y-h//2+2)],fill='#95684b' if level<3 else '#6c8063')
 d.line((x-w//2-3,y-h//2+2,x,y-h//2-11,x+w//2+3,y-h//2+2),fill=INK,width=2)
 for dy in range(3,11,3): d.line((x-w//2+dy,y-h//2-dy//2,x+w//2-dy,y-h//2-dy//2),fill='#b88559' if level<3 else '#8da07a')
 d.rectangle((x-2,y+1,x+2,y+h//2),fill='#9b744d');d.rectangle((x-8,y-1,x-4,y+3),fill='#91aaa2');d.rectangle((x+4,y-1,x+8,y+3),fill='#91aaa2')
def field(d,box):
 x,y,w,h=box;d.rectangle((x-3,y-3,x+w+3,y+h+3),fill='#a89568');d.rectangle((x,y,x+w,y+h),fill='#a8865c')
 for yy in range(int(y+4),int(y+h),7):
  d.line((x+2,yy,x+w-2,yy),fill='#7e6949')
  for xx in range(int(x+5),int(x+w-2),9):
   d.line((xx,yy,xx,yy-3),fill='#667d4e');d.line((xx-2,yy-2,xx,yy),fill='#b9c389')
def waves(d,box,seed=6):
 x,y,w,h=box;r=random.Random(seed)
 for _ in range(28):
  px=r.randrange(int(x),int(x+w));py=r.randrange(int(y),int(y+h));d.line((px,py,px+5,py),fill='#b6d1ba')
def region_point(id,p):
 bounds={'farm':(0,0,1536,1024),'village':(0,0,1280,896),'lake':(864,384,544,512)}[id]
 return (32+(p[0]-bounds[0])/bounds[2]*448,24+(p[1]-bounds[1])/bounds[3]*272)
def region_rect(id,r):
 p=region_point(id,r[:2]);q=region_point(id,(r[0]+r[2],r[1]+r[3]));return (p[0],p[1],q[0]-p[0],q[1]-p[1])
def save(im,name): im.resize((1024,640),Image.NEAREST).save(OUT/f'{name}.png')
# World overview: topological diagram of separate scene maps.
im,d=paper(180);terrain(d,(52,49,402,231));cluster(d,(67,105,62,119),35,18);cluster(d,(333,51,92,39),19,19)
water(d,[(321,37),(326,94),(346,125),(336,165),(354,193),(371,237),(385,282)],13)
d.ellipse((336,197,414,245),fill='#577e78');d.ellipse((339,199,411,242),fill=WATER);waves(d,(347,205,48,30))
road(d,[(211,230),(218,202),(231,174),(242,146),(255,104)],10);road(d,[(240,151),(305,149),(337,144),(405,140)],8);road(d,[(218,203),(154,185),(113,168)],7);road(d,[(255,104),(317,88),(398,70)],7);road(d,[(218,215),(280,237),(342,275)],7)
for x,y in [(242,98),(260,91),(277,103)]:house(d,x,y,.8)
field(d,(209,223,37,26));house(d,209,206,1.15)
for x,y in [(153,232),(175,253),(289,254),(300,54),(416,274),(75,64)]: tree(d,x,y)
# Soft unknown land masses reveal no landmarks or dungeon layouts.
for x,y in [(448,255),(447,141)]:
 d.ellipse((x-27,y-19,x+27,y+19),fill='#d0c49e');d.arc((x-19,y-12,x+21,y+13),15,290,fill='#a79a78',width=1)
save(im,'world')
for name in ['farm','village','lake']:
 im,d=paper(210+len(name));terrain(d,(32,24,448,272))
 if name=='farm':
  road(d,[region_point(name,p) for p in [(480,960),(480,440),(480,192)]],14)
  road(d,[region_point(name,p) for p in [(224,440),(968,440)]],13)
  field(d,region_rect(name,(544,512,320,192)));house(d,*region_point(name,(656,376)),1.5);house(d,*region_point(name,(356,392)),1.0)
  cluster(d,region_rect(name,(100,100,260,220)),26,2);cluster(d,region_rect(name,(1150,80,250,290)),24,3);cluster(d,region_rect(name,(100,720,260,220)),20,4)
  q=region_rect(name,(970,440,280,280));x,y,w,h=q;d.ellipse((x,y,x+w,y+h),fill='#a7b58c');d.ellipse((x+3,y+3,x+w-3,y+h-3),fill='#577e78');d.ellipse((x+5,y+5,x+w-5,y+h-5),fill=WATER);waves(d,(x+12,y+15,w-25,h-30))
  road(d,[region_point(name,p) for p in [(1020,744),(1104,768),(1264,720)]],6)
 elif name=='village':
  road(d,[region_point(name,p) for p in [(640,826),(640,300)]],16);road(d,[region_point(name,p) for p in [(90,480),(1184,480)]],16)
  water(d,[region_point(name,p) for p in [(880,0),(880,896)]],28)
  for p in [(290,330),(520,330)]:house(d,*region_point(name,p),1.5)
  house(d,*region_point(name,(1090,320)),1.05);field(d,region_rect(name,(160,620,290,50)))
  cluster(d,region_rect(name,(80,80,660,180)),35,5);cluster(d,region_rect(name,(60,740,360,90)),14,6)
  x,y=region_point(name,(628,524));d.ellipse((x-27,y-20,x+27,y+20),outline='#c7ae7a',width=2)
 else:
  q=region_rect(name,(976,416,288,320));x,y,w,h=q;d.ellipse((x-5,y-5,x+w+5,y+h+5),fill='#a4aa7e');d.ellipse((x-1,y-1,x+w+1,y+h+1),fill='#577e78');d.ellipse((x+3,y+3,x+w-3,y+h-3),fill=WATER);waves(d,(x+18,y+20,w-40,h-40))
  road(d,[region_point(name,p) for p in [(912,688),(960,756),(1104,784),(1296,688)]],8)
  cluster(d,region_rect(name,(904,400,66,180)),16,8);cluster(d,region_rect(name,(1290,400,55,160)),16,9)
 save(im,name)
for name,color in [('mist_forest','#a8b383'),('lake_ruins','#c4c0a1'),('old_temple','#c5ba94'),('cave','#c7ba9d'),('home','#dbc193'),('greenhouse','#c3c49a')]:
 im,d=paper(310+len(name));terrain(d,(36,27,440,266),color)
 if name=='mist_forest':
  cluster(d,(58,55,380,211),130,22);road(d,[(116,250),(129,214),(181,203),(204,161),(275,174),(315,124),(403,109)],9);water(d,[(344,45),(328,86),(365,140),(355,220),(388,282)],11)
 elif name in ['lake_ruins','old_temple']:
  for x,y,w,h in [(83,63,135,91),(253,74,166,78),(200,191,150,77)]:
   d.rectangle((x,y,x+w,y+h),fill='#a59e7e',outline=INK,width=3);d.rectangle((x+6,y+6,x+w-6,y+h-6),fill='#d6ccac',outline='#b4a784')
   for xx in range(x+12,x+w-8,16):d.line((xx,y+8,xx,y+h-8),fill='#c5bc9b')
  road(d,[(114,256),(151,196),(249,178),(352,114)],12)
  if name=='lake_ruins':water(d,[(330,45),(329,172),(406,221),(409,281)],16)
  else:
   for x,y in [(68,203),(392,250),(389,53),(62,48)]:tree(d,x,y)
 elif name=='cave':
  # Area-only sketch deliberately has no undiscovered cave route or chest data.
  for x,y,w,h in [(75,69,127,68),(281,79,147,74),(154,211,175,54)]:
   d.polygon([(x,y+12),(x+24,y),(x+w-11,y+4),(x+w,y+28),(x+w-21,y+h),(x+19,y+h-5)],fill='#998f76',outline=INK)
   d.line((x+17,y+20,x+w-17,y+20),fill='#b7a787',width=3)
 elif name=='home':
  # Real room/furniture footprints are drawn from HomeLayout after player upgrades/moves.
  pass
 else:
  d.rectangle((100,51,417,264),fill='#b5ba94',outline=INK,width=3)
  for x in range(108,417,31):d.line((x,54,x,260),fill='#e0ddbc',width=2)
  for y in range(57,260,35):d.line((103,y,414,y),fill='#8eaa9c',width=2)
  for x in [139,220,301,381]:
   for y in [117,170,220]:tree(d,x,y)
 save(im,name)
# Original compact symbols used by dynamic progress/POI overlays.
for name in ['house_1','house_2','house_3','house_4','market','village','lake','forest','mine','ruins','temple','greenhouse','sign','field','workshop','barn','well','dock','bridge','lantern','unknown','bed','kitchen','pin']:
 im=Image.new('RGBA',(40,40));d=ImageDraw.Draw(im)
 if name.startswith('house_') or name in ['market','village','workshop','barn']:
  house(d,20,25,1.05,int(name[-1]) if name.startswith('house_') else 1)
  if name.startswith('house_') and int(name[-1])>=2:
   d.rectangle((2,24,10,33),fill='#e4cea0',outline=INK);d.polygon([(1,24),(6,19),(11,24)],fill='#95684b' if name=='house_2' else '#6c8063',outline=INK)
  if name=='house_4':
   d.rectangle((30,24,38,33),fill='#e4cea0',outline=INK);d.polygon([(29,24),(34,19),(39,24)],fill='#6c8063',outline=INK)
   d.line((20,2,20,9),fill='#e7b96b',width=2);d.line((17,5,23,5),fill='#e7b96b',width=2)
 elif name=='forest':
  for x,y in [(11,25),(25,24),(19,34)]:tree(d,x,y)
 elif name=='lake':
  d.ellipse((3,12,37,31),fill=INK);d.ellipse((5,14,35,29),fill=WATER);d.line((12,21,21,21),fill='#d1e0c4',width=2)
 elif name=='mine':
  d.polygon([(3,32),(7,17),(17,5),(27,9),(37,32)],fill='#a3997b',outline=INK);d.ellipse((12,17,29,38),fill='#5e6053');d.rectangle((13,29,28,37),fill='#5e6053');d.line((13,21,28,21),fill='#c4a16c',width=3)
 elif name=='greenhouse':
  d.rectangle((5,15,35,34),fill='#bad0b8',outline=INK,width=2);d.polygon([(4,15),(20,4),(36,15)],fill='#a6c5b4',outline=INK)
  for x in [13,21,29]:d.line((x,15,x,33),fill='#e8ddb6',width=2)
  d.line((5,24,34,24),fill='#e8ddb6',width=2)
 elif name in ['bridge','dock']:
  d.rectangle((4,11,35,31),fill='#ab8a5e',outline=INK,width=2)
  for x in range(8,34,5):d.line((x,12,x,30),fill='#dcc392',width=2)
  if name=='bridge':d.line((4,9,35,9),fill=INK,width=3);d.line((4,33,35,33),fill=INK,width=3)
 elif name=='lantern':
  d.line((5,8,5,36),fill=INK,width=3);d.line((35,8,35,36),fill=INK,width=3);d.line((4,8,36,8),fill=INK,width=2)
  for x in [11,20,29]:d.rectangle((x-3,15,x+3,25),fill='#e4b364',outline=INK);d.line((x,8,x,15),fill=INK)
 elif name=='field':field(d,(4,9,32,22))
 elif name=='unknown':
  d.ellipse((3,9,37,31),fill='#c5bc9a');d.arc((12,8,28,23),180,500,fill='#8b7d61',width=3);d.rectangle((18,28,21,31),fill='#8b7d61')
 elif name=='well':
  d.ellipse((8,22,32,35),fill='#b1ac8c',outline=INK,width=2);d.rectangle((10,14,13,30),fill=INK);d.rectangle((28,14,31,30),fill=INK);d.polygon([(5,15),(20,5),(36,15)],fill='#98734b',outline=INK)
 elif name in ['ruins','temple']:
  d.rectangle((7,31,34,35),fill='#b7ad8e',outline=INK)
  for x in [10,26]:d.rectangle((x,12,x+5,30),fill='#d0c7a8',outline=INK)
  d.polygon([(5,12),(20,3),(36,12)],fill='#b6ac8c',outline=INK)
 elif name=='bed':
  d.rectangle((8,6,32,35),fill='#a68b5c',outline=INK,width=2);d.rectangle((11,18,29,31),fill='#8b9a77');d.rectangle((11,9,29,16),fill='#efe2bd')
 elif name=='kitchen':
  d.rectangle((4,16,36,34),fill='#e8d5aa',outline=INK,width=2);d.rectangle((3,12,37,16),fill='#9eaa94');d.ellipse((7,6,20,13),fill=INK)
 else:
  d.rectangle((10,7,31,24),fill='#d0b787',outline=INK,width=2);d.rectangle((18,24,22,35),fill=INK)
 im.save(OUT/f'icon_{name}.png')
print('Generated',len(list(OUT.glob('*.png'))),'original parchment/symbol PNGs')
