"""Original cottage pixel furnishings, hand-programmed from the project's palette.
User-provided references guide warmth, material layering and room organization only.
No image extraction, stock/game assets, image-generation API or AI-image claim.
"""
from pathlib import Path
import random
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[1]
D=R/'assets/housing/interior'
D.mkdir(parents=True,exist_ok=True)
O='#49352b'; DARK='#624535'; WOOD='#9a6b45'; WARM='#c29665'; LIGHT='#e1bb84'; PAPER='#ebdbb5'
def canvas(w,h):
 im=Image.new('RGBA',(w//2,h//2));return im,ImageDraw.Draw(im)
def save(im,name): im.resize((im.width*2,im.height*2),Image.NEAREST).save(D/(name+'.png'))
def shadow(d,box):
 x,y,w,h=box;d.ellipse((x-2,y+h-4,x+w+3,y+h+1),fill=(35,28,24,48));d.ellipse((x,y+h-3,x+w,y+h),fill=(35,28,24,74))
def wood(d,box,seed=1,palette=(O,DARK,WOOD,WARM,LIGHT)):
 x,y,w,h=box;r=random.Random(seed);a,b,c,e,f=palette
 d.rectangle((x,y,x+w-1,y+h-1),fill=a);d.rectangle((x+1,y+1,x+w-2,y+h-3),fill=c)
 d.line((x+1,y+1,x+w-2,y+1),fill=f);d.line((x+1,y+2,x+w-2,y+2),fill=e)
 for j in range(y+4,y+h-3,5):
  d.line((x+2,j,x+w-3,j),fill=b)
  if w>12:
   start=r.randint(x+3,x+w-8);d.line((start,j-2,min(start+r.randint(4,11),x+w-4),j-2),fill=e)
 d.line((x+w-2,y+3,x+w-2,y+h-3),fill=b)
def pot(d,x,y,s=1,flowers=False):
 d.ellipse((x-5*s,y-2*s,x+6*s,y+2*s),fill=(38,34,22,65))
 d.polygon([(x-4*s,y-8*s),(x+5*s,y-8*s),(x+3*s,y),(x-2*s,y)],fill='#926347')
 d.rectangle((x-5*s,y-10*s,x+6*s,y-7*s),fill='#c49065');d.line((x-3*s,y-6*s,x-2*s,y-1*s),fill='#d5aa78',width=s)
 for ox,oy in [(-6,-15),(4,-20),(-1,-25),(8,-12),(-7,-23)]:
  d.line((x,y-10*s,x+ox*s,y+oy*s),fill='#52623b',width=s)
  d.polygon([(x+ox*s,y+oy*s),(x+(ox-4)*s,y+(oy-4)*s),(x+(ox-2)*s,y+(oy-6)*s),(x+(ox+3)*s,y+(oy-2)*s)],fill='#6f854b')
  d.line((x+ox*s,y+oy*s,x+(ox-1)*s,y+(oy-3)*s),fill='#a2ad68',width=s)
  if flowers:d.rectangle((x+(ox-1)*s,y+(oy-5)*s,x+(ox+1)*s,y+(oy-3)*s),fill='#dca584')
def book(d,x,y,w=8,h=5,color='#66776e'):
 d.rectangle((x,y,x+w,y+h),fill=O);d.rectangle((x+1,y,x+w-1,y+h-1),fill=color)
 d.line((x+1,y+1,x+w-1,y+1),fill=PAPER);d.line((x+w-2,y+2,x+w-2,y+h-1),fill='#b4a181')
def rug(w,h,name,base='#486c5b',accent='#b5a270'):
 im,d=canvas(w,h);w//=2;h//=2
 d.rectangle((1,1,w-2,h-2),fill='#473d36');d.rectangle((2,2,w-3,h-3),fill=accent);d.rectangle((4,4,w-5,h-5),fill=base)
 d.rectangle((6,6,w-7,h-7),outline=accent);d.rectangle((8,8,w-9,h-9),outline='#7a865c')
 for x in range(6,w-5,5):
  d.line((x,2,x,3),fill=PAPER);d.line((x,h-4,x,h-3),fill=PAPER)
 for y in range(8,h-7,6):
  for x in range(10,w-9,8):d.polygon([(x,y-1),(x+2,y+1),(x,y+3),(x-2,y+1)],fill=accent)
 cx=w//2;cy=h//2
 for offset,color in [(10,accent),(7,base),(4,accent)]:d.polygon([(cx,cy-offset),(cx+offset,cy),(cx,cy+offset),(cx-offset,cy)],fill=color)
 save(im,name)
# Sixteen-pixel native plank tiles become the existing thirty-two-pixel map cells.
for polished in [False,True]:
 im=Image.open(R/'assets/tilesets/ground.png').convert('RGBA');tile=Image.new('RGBA',(16,16));d=ImageDraw.Draw(tile);r=random.Random(401 if polished else 127)
 palette=['#aa784e','#b38155','#bc8b5d','#c39466'] if polished else ['#987047','#a7794e','#b38457','#ac7d51']
 for row in range(2):
  y=row*8;d.rectangle((0,y,15,y+7),fill=palette[row+1]);d.line((0,y,15,y),fill='#705035');d.line((0,y+1,15,y+1),fill='#c79c70')
  joint=4 if row==0 else 12;d.line((joint,y+1,joint,y+7),fill='#805839')
  for i in range(5):
   x=r.randint(0,12);yy=y+r.randint(3,6);d.line((x,yy,min(15,x+r.randint(2,7)),yy),fill=palette[r.randrange(len(palette))])
  d.point((joint+2,y+3),fill='#79573b')
 im.paste(tile.resize((32,32),Image.NEAREST),(224,0));im.save(D/('floor_polished_atlas.png' if polished else 'floor_oak_atlas.png'))
# Transparent wall cutaway; floor stays a real TileMap and props have individual footprints.
for level in range(1,5):
 im,d=canvas(640,464)
 d.rectangle((0,0,319,39),fill='#3c332c');d.rectangle((8,8,311,35),fill='#c19d70')
 for x in range(9,312,10):
  d.rectangle((x,9,x+8,34),fill=('#b99368' if (x//10)%3 else '#c9a77a'));d.line((x,10,x,33),fill='#99714f');d.line((x+1,10,x+1,31),fill='#dbb789')
 for y in [4,6,34,36]:d.rectangle((3,y,316,y+2),fill=O if y in [4,36] else '#a5784b')
 for x in [2,14,304,316]:
  d.rectangle((x,4,x+3,43),fill=O);d.line((x+1,6,x+1,39),fill='#b1895a')
 # Side and foreground cutaway wall beams with a true doorway recess.
 for x in [0,304]:
  if x==0:
   spans=[(40,215)] if level==1 else [(40,135),(184,215)]
  else:spans=[(40,215)]
  for a,b in spans:
   d.rectangle((x,a,x+15,b),fill='#514131');d.rectangle((x+2,a,x+11,b),fill='#99784f');d.line((x+3,a,x+3,b),fill='#c4a16d')
   for y in range(a+8,b,16):d.line((x+5,y,x+10,y+2),fill='#725537')
 for a,b in [(0,145),(175,319)]:
  d.rectangle((a,216,b,231),fill=O);d.rectangle((a+2,217,b-2,226),fill='#a07c51');d.line((a+2,218,b-2,218),fill='#d6b37b')
 d.rectangle((146,215,174,231),fill='#4d3a2a')
 for y in [218,222,226,230]:d.rectangle((147,y,173,y+2),fill='#af8856');d.line((148,y,172,y),fill='#e2be84')
 # Small decorative nail heads keep large beams from reading as flat rectangles.
 for x in [7,20,299,311]:
  for y in [7,36,220]:d.rectangle((x,y,x+1,y+1),fill='#493c2d');d.point((x,y),fill='#d4b982')
 save(im,'walls_'+str(level))
# Window: leaded glass, layered frame, curtains and sill plants.
im,d=canvas(88,64);wood(d,(2,2,40,27),8)
d.rectangle((6,5,37,22),fill='#314c51');d.rectangle((7,6,36,21),fill='#7baaa4');d.rectangle((8,7,35,12),fill='#aacbc0')
for x in [10,20,30]:d.line((x,8,x-3,20),fill='#c8dfcc')
d.line((22,5,22,22),fill='#dfc193',width=2);d.line((6,14,38,14),fill='#dfc193',width=2)
d.polygon([(2,2),(11,2),(11,7),(8,14),(9,22),(4,23)],fill='#d0b889');d.line((6,3,6,12),fill='#e6d5a8')
d.polygon([(34,2),(42,2),(40,23),(35,21),(36,14),(32,7)],fill='#d0b889');d.line((38,3,38,12),fill='#edddb7')
wood(d,(0,25,44,5),5);save(im,'window')
# Shelf / dresser, ceramic dishes and varied book spines.
im,d=canvas(136,80);shadow(d,(2,6,64,31));wood(d,(3,2,62,35),41)
for yy in [6,17]:
 d.rectangle((7,yy,60,yy+8),fill='#523d2e')
 for j,x in enumerate(range(9,58,8)):
  if yy==6:
   d.ellipse((x,yy+2,x+5,yy+6),fill=['#9da58b','#c0ab7c','#7b9990'][j%3]);d.line((x+1,yy+2,x+4,yy+2),fill=PAPER)
  else:
   d.rectangle((x,yy+1,x+4,yy+6),fill=['#718977','#947965','#b69872'][j%3]);d.line((x+1,yy+2,x+3,yy+2),fill='#dcc89e')
for x in [8,34]:
 d.rectangle((x,28,x+24,33),fill='#765339');d.rectangle((x+1,28,x+23,31),fill='#af8253');d.rectangle((x+11,30,x+13,31),fill='#e7c68a')
d.ellipse((49,0,57,5),fill='#b7ad8d');d.ellipse((51,0,55,2),fill='#ddd1b2');save(im,'dresser')
# Bed has a detailed quilt, slats, pillow seams and carved posts in the original footprint.
for quilt in [False,True]:
 im,d=canvas(96,128);shadow(d,(1,3,45,59));wood(d,(2,1,43,61),31)
 d.rectangle((5,6,41,59),fill='#d2bd91');d.rectangle((7,9,39,22),fill='#eee2bf')
 d.line((8,10,38,10),fill='#fff0ce');d.line((8,20,38,20),fill='#b5a789');d.line((23,10,23,20),fill='#d0c5a6')
 d.rectangle((5,24,41,58),fill='#657c62' if not quilt else '#8f655b')
 for y in range(25,58,5):
  d.line((6,y,40,y),fill='#8e9c75' if not quilt else '#bd8e76')
  if quilt:
   for x in range(8,40,6):d.rectangle((x,y+1,x+2,y+3),fill='#d7b99c' if (x+y)%2 else '#6e6452')
  else:
   for x in [11,34]:d.line((x,y+1,x,y+3),fill='#b4bb93')
 d.rectangle((5,23,41,27),fill='#a8b18e' if not quilt else '#dbc29c');d.line((6,24,40,24),fill=PAPER)
 for x in [2,42]:
  d.rectangle((x,0,x+2,63),fill=O);d.line((x+1,3,x+1,60),fill='#b9935e');d.rectangle((x-1,0,x+3,3),fill='#dfbb7f')
 save(im,'bed_quilt' if quilt else 'bed')
# Dining table, runner, earthenware and independent chairs.
im,d=canvas(120,84);shadow(d,(5,12,50,28));wood(d,(8,5,44,30),19)
for x in [9,47]:d.rectangle((x,31,x+3,40),fill=DARK);d.line((x+1,32,x+1,38),fill=WOOD)
d.rectangle((23,7,34,31),fill='#8b6556');d.line((24,8,24,30),fill='#c59c78');d.line((33,8,33,30),fill='#d1ab82')
d.ellipse((20,12,37,24),fill='#5b4d36');d.ellipse((21,12,36,22),fill='#b29158');d.ellipse((23,13,34,20),fill='#6c7845')
for x,y,c in [(26,16,'#cf9556'),(30,15,'#a95643'),(28,19,'#dcb568')]:d.rectangle((x,y,x+2,y+2),fill=c)
d.ellipse((39,9,45,15),fill='#b3b69a');d.ellipse((40,10,44,13),fill='#725744');save(im,'dining_table')
for name,flip in [('chair_left',False),('chair_right',True)]:
 im,d=canvas(28,48);wood(d,(2,2,10,18),5);d.rectangle((4,5,9,13),fill='#6c8066');d.line((5,6,5,12),fill='#9da87d');wood(d,(1,16,12,5),12)
 for x in [2,10]:d.rectangle((x,20,x+1,23),fill=O)
 if flip:im=im.transpose(Image.FLIP_LEFT_RIGHT)
 save(im,name)
# Kitchen: stone backsplash, stove with iron pan, sink/tap, worktop and lower cabinetry.
im,d=canvas(128,72);shadow(d,(1,8,62,26))
d.rectangle((1,0,62,15),fill='#a99a79')
for y in range(1,15,5):
 for x in range(2+(3 if y%2 else 0),62,7):d.rectangle((x,y,x+5,y+3),fill='#c3b390');d.line((x,y,x+5,y),fill='#d6c5a1')
wood(d,(2,14,59,19),20);d.rectangle((1,13,62,17),fill='#c3af88');d.line((2,13,61,13),fill='#ead3a6')
for x in [5,24,43]:
 d.rectangle((x,20,x+16,29),fill='#755139');d.rectangle((x+1,20,x+15,27),fill='#a4764e');d.rectangle((x+7,22,x+9,23),fill='#d4b47f')
d.rectangle((3,9,24,16),fill='#4c5550');d.rectangle((5,10,22,15),fill='#76827a');d.ellipse((8,10,16,14),fill='#333c37');d.ellipse((9,9,17,13),fill='#88958a');d.line((17,10,22,8),fill='#444d46',width=2)
d.rectangle((31,10,52,16),fill='#5e736d');d.rectangle((33,11,50,15),fill='#91b1a5');d.line((36,12,47,12),fill='#d9e4cb')
d.line((41,10,41,6),fill='#a3b5a6',width=2);d.line((41,6,46,6),fill='#d0d5b8',width=2);d.line((46,6,46,9),fill='#81998b')
wood(d,(55,5,7,10),4);d.rectangle((57,2,59,7),fill='#899968');d.ellipse((54,1,61,4),fill='#658253')
d.rectangle((8,22,18,28),fill='#3e4540');d.rectangle((10,23,16,26),fill='#b3814f');save(im,'kitchen')
# Fireplace and hearth; warm stone has mortar, soot, embers and a stacked-wood niche.
for grand in [False,True]:
 im,d=canvas(96,112);shadow(d,(3,18,42,36));d.rectangle((7,1,40,39),fill='#55493d')
 for y in range(2,39,6):
  for x in range(8+(4 if y%12 else 0),39,9):
   d.rectangle((x,y,min(x+7,39),y+4),fill=['#7a7360','#8b816c','#6d6a59'][(x+y)//3%3]);d.line((x,y,min(x+7,39),y),fill='#a0967a')
 wood(d,(2,18,44,6),23);d.rectangle((9,26,38,47),fill='#413b31');d.rectangle((12,29,35,46),fill='#241f1c')
 d.rectangle((10,45,37,50),fill='#85806b');d.line((11,46,36,46),fill='#b0a38a')
 for x in [16,22,28]:d.rectangle((x,42,x+6,44),fill='#714a2c');d.line((x,42,x+5,42),fill='#bd7b3d')
 for x,h in [(16,7),(21,13),(27,10),(31,6)]:
  d.polygon([(x,43),(x-2,38),(x+1,43-h),(x+4,39),(x+3,43)],fill='#d88a36');d.polygon([(x+1,43),(x+1,38),(x+2,35),(x+3,43)],fill='#f0c45e')
 if grand:
  d.ellipse((18,8,30,18),fill='#473f32');d.ellipse((19,8,29,17),fill='#bba878');d.line((24,10,24,13),fill=O);d.line((24,13,27,14),fill=O)
 save(im,'fireplace_grand' if grand else 'fireplace')
# Sofa, mail writing desk, storage chest and side study furniture.
im,d=canvas(88,56);shadow(d,(0,12,44,14));wood(d,(1,11,42,14),11)
d.rectangle((3,2,40,19),fill='#465e50');d.rectangle((5,3,38,16),fill='#788d69');d.line((6,4,37,4),fill='#aab18b')
for x in [4,22]:d.rectangle((x,15,x+17,23),fill='#8a9b74');d.line((x+1,16,x+16,16),fill='#b9bd94');d.line((x+2,22,x+15,22),fill='#657958')
for x in [0,38]:d.rectangle((x,10,x+5,25),fill='#59725a');d.line((x+1,11,x+4,11),fill='#a9b58c')
d.rectangle((6,6,14,14),fill='#bc9b74');d.line((8,8,12,12),fill='#e3c6a1');save(im,'sofa')
im,d=canvas(88,56);shadow(d,(3,11,38,14));wood(d,(3,4,38,20),10)
book(d,8,7,13,8,'#6e8b7d');d.rectangle((24,7,34,15),fill=PAPER)
for yy in [9,11,13]:d.line((26,yy,32,yy),fill='#ab9065')
d.rectangle((35,5,37,10),fill='#685143');d.line((37,4,39,1),fill='#c6c3a4')
for x in [5,37]:d.rectangle((x,23,x+2,27),fill=O)
save(im,'mail_desk')
im,d=canvas(64,80);shadow(d,(2,11,28,27));wood(d,(3,9,26,27),66)
d.polygon([(3,9),(6,4),(25,4),(28,9)],fill='#af8855');d.line((6,5,25,5),fill='#dbb47c')
for x in [7,23]:d.rectangle((x,6,x+2,34),fill='#735940');d.line((x+1,7,x+1,33),fill='#bfad78')
d.rectangle((14,18,18,24),fill='#d5b778');d.rectangle((15,20,17,23),fill='#66553d');save(im,'storage_chest')
for level,width in [(2,104),(3,192),(4,256)]:
 im,d=canvas(width,64);w=width//2;shadow(d,(1,11,w-2,19));wood(d,(2,8,w-4,21),level*7)
 for x in [4,w-8]:d.rectangle((x,28,x+3,31),fill=DARK)
 book(d,7,11,12,8,'#778a6b');book(d,22,12,10,7,'#a17f62')
 if w>70:
  d.rectangle((w//2-11,10,w//2+9,21),fill=PAPER)
  for y in [13,16,19]:d.line((w//2-8,y,w//2+6,y),fill='#a18e66')
 for x in [w-18,w-10]:
  d.rectangle((x,9,x+3,13),fill='#c5b78c');d.ellipse((x,7,x+3,10),fill='#e9dfb8')
 save(im,'study_desk_'+str(level))
im,d=canvas(40,64);pot(d,10,31,1,True);save(im,'plant')
im,d=canvas(32,48);wood(d,(3,16,10,6),2);d.rectangle((7,5,9,17),fill='#95774f');d.polygon([(2,5),(4,1),(12,1),(14,5),(13,9),(3,9)],fill='#e8d3a4');d.line((4,3,12,3),fill='#fff0c6');save(im,'lamp')
im,d=canvas(64,48);wood(d,(1,0,30,22),27)
for i,x in enumerate(range(4,29,4)):
 d.rectangle((x,3,x+2,17),fill=['#65786a','#987966','#a89263','#777c85'][i%4]);d.line((x,5,x+2,5),fill='#d7c5a0')
d.line((3,18,28,18),fill='#d8b581');save(im,'bookcase')
rug(240,126,'main_rug');rug(96,144,'bed_rug','#8a5f52','#c4a17c');rug(176,176,'study_rug','#716d74','#b9a179')
# Installed paper wall style remains an overlay and never alters collision/floor geometry.
im,d=canvas(608,64);d.rectangle((0,0,303,31),fill='#b3b695')
for x in range(4,303,12):
 d.line((x,3,x+6,26),fill='#728566');d.line((x+2,12,x+7,7),fill='#d9d5ad');d.ellipse((x+2,7,x+5,10),fill='#98a07e')
d.rectangle((0,27,303,31),fill='#8b7050');d.line((0,27,303,27),fill='#d8bc87');save(im,'wallpaper_sage')
# Side-room shells carry the same carved beams, panel grain and foreground shading.
for level,w,h in [(2,128,160),(3,224,288),(4,288,352)]:
 im,d=canvas(w+24,h+60);ww=im.width;hh=im.height
 d.rectangle((0,0,ww-1,23),fill='#44352c');d.rectangle((5,5,ww-7,22),fill='#c1a173')
 for x in range(6,ww-7,8):
  d.rectangle((x,6,x+6,22),fill='#bd986a' if x%3 else '#c8a579');d.line((x,6,x,22),fill='#92704d');d.line((x+1,7,x+1,21),fill='#dfbe8b')
 for y in [1,3,21]:d.line((2,y,ww-3,y),fill='#725137' if y!=3 else '#c29e6b',width=2)
 d.rectangle((0,22,5,hh-1),fill='#49372d');d.rectangle((2,24,4,hh-4),fill='#b49361')
 d.rectangle((4,hh-7,ww-1,hh-1),fill='#49382d');d.rectangle((5,hh-6,ww-1,hh-3),fill='#a27c4d');d.line((5,hh-6,ww-1,hh-6),fill='#d9b87f')
 for y in range(31,hh-8,12):d.line((2,y,4,y+2),fill='#735138')
 save(im,'extension_walls_'+str(level))
im,d=canvas(32,64);shadow(d,(1,12,14,19));wood(d,(1,9,14,20),66)
d.polygon([(1,9),(3,5),(12,5),(14,9)],fill='#ad885b');d.line((3,6,12,6),fill='#e2be87')
for x in [4,11]:d.rectangle((x,7,x+1,28),fill='#6b543b');d.line((x,8,x,26),fill='#c4ad79')
d.rectangle((7,16,9,21),fill='#dfbf7e');d.point((8,19),fill='#65513c');save(im,'storage_slim')
im,d=canvas(128,160)
for i in range(5):
 d.polygon([(5+i*3,0),(23+i*3,0),(58+i*2,78),(30+i*2,78)],fill=(244,215,145,5+i*2))
save(im,'sunbeam')

# Room-zoning accents: kitchen stonework, dining weave and a low bedroom screen.
rug(80,104,'study_rug_2','#607565','#b5a077')
rug(224,224,'study_rug_4','#626a72','#bba37a')
rug(176,104,'dining_rug','#866b57','#c5ab7a')
im,d=canvas(144,80)
for y in range(0,40,8):
 for x in range(0,72,8):
  d.rectangle((x,y,x+7,y+7),fill='#b2a183' if (x//8+y//8)%2 else '#c5b594');d.line((x,y,x+7,y),fill='#e0d1b1');d.line((x,y,x,y+7),fill='#dbc8a5');d.line((x+7,y,x+7,y+7),fill='#8f826a');d.line((x,y+7,x+7,y+7),fill='#9e9074')
save(im,'kitchen_tiles')
im,d=canvas(56,152)
d.rectangle((4,1,10,43),fill=O);d.rectangle((5,3,9,41),fill='#bd9c70')
for y in range(5,40,7):d.line((6,y,8,y+3),fill='#95704c')
d.rectangle((10,3,17,38),fill='#c7b58e')
for y in range(4,38,5):d.line((11,y,16,y),fill='#e6d4ad')
wood(d,(4,39,23,5),17)
d.rectangle((4,43,7,70),fill='#6c4b36');d.line((5,44,5,69),fill='#bf9962');d.rectangle((3,69,9,75),fill='#8d6b49')
# A tucked curtain leaves the bed interaction and walking opening clear.
d.polygon([(10,44),(16,44),(14,49),(12,57),(9,57)],fill='#a6a985');d.line((12,45,11,54),fill='#d8d5ad')
save(im,'bedroom_divider')

# High-tier finishes retain identical footprints and base silhouettes.
def native(name):
 source=Image.open(D/(name+'.png')).convert('RGBA')
 return source.resize((source.width//2,source.height//2),Image.NEAREST)
im=native('sofa');colors={'#465e50':'#365b62','#788d69':'#607f83','#aab18b':'#aabbb1','#8a9b74':'#799798','#b9bd94':'#baceb6','#657958':'#4c7078','#59725a':'#436a73','#a9b58c':'#9bb8b4'}
for y in range(im.height):
 for x in range(im.width):
  pixel=im.getpixel((x,y))
  if pixel[3]!=255:continue
  key='#%02x%02x%02x'%pixel[:3]
  if key in colors:im.putpixel((x,y),tuple(bytes.fromhex(colors[key][1:]))+(255,))
d=ImageDraw.Draw(im)
for x in [0,38]:
 d.line((x+1,10,x+4,10),fill='#dbbc7e');d.line((x+1,12,x+4,12),fill='#aa8d59');d.line((x+1,24,x+4,24),fill='#e1c88f')
d.rectangle((29,5,36,13),fill='#b6bdac');d.line((30,6,35,11),fill='#e4dcb9');d.line((30,11,35,6),fill='#90a89b')
for cx in [13,30]:
 cy=18;d.polygon([(cx,cy-3),(cx+1,cy-1),(cx+3,cy),(cx+1,cy+1),(cx,cy+3),(cx-1,cy+1),(cx-3,cy),(cx-1,cy-1)],fill='#ddc38e');d.point((cx,cy),fill='#f5e3b5')
for x in range(7,37,3):d.point((x,22),fill='#b6c9ba')
save(im,'sofa_estate')
im=native('sofa');d=ImageDraw.Draw(im);d.rectangle((29,5,36,13),fill='#c5af85');d.line((30,6,35,11),fill='#e8d2ab');d.line((30,11,35,6),fill='#9b835f')
for x in [8,26]:d.line((x,17,x+12,17),fill='#c1c6a0')
save(im,'sofa_cottage')
im=native('window');d=ImageDraw.Draw(im)
for y in range(6,22):d.line((7,y,36,y),fill=('#91b5b0' if y<11 else '#c3d6bd'))
d.polygon([(7,17),(12,12),(17,16),(23,11),(30,16),(36,14),(36,21),(7,21)],fill='#7e9b7c')
d.polygon([(7,20),(17,17),(25,19),(31,16),(36,18),(36,21),(7,21)],fill='#a8b798')
for x in [16,27]:d.line((x,5,x,22),fill='#e2c68d',width=2)
d.line((6,14,38,14),fill='#dcc18b');d.line((7,6,36,6),fill='#f2dfb0')
for x in [5,37]:
 d.line((x,3,x,20),fill='#f1e0bb');d.point((x+1,8),fill='#bdbd99');d.point((x+1,15),fill='#bdbd99')
wood(d,(0,25,44,5),49);d.rectangle((14,26,29,28),fill='#b89f66');d.line((15,26,28,26),fill='#f0d79f')
save(im,'window_estate')
im=native('window');d=ImageDraw.Draw(im);d.rectangle((5,25,15,28),fill='#9b7450')
for x in [7,11,14]:d.line((x,24,x+1,20),fill='#637c4d');d.rectangle((x,19,x+2,21),fill='#d9b79d');d.point((x+1,20),fill='#f0d3b3')
save(im,'window_cottage')
im=native('kitchen');colors={'#9a6b45':'#b5ad92','#c29665':'#d8caab','#e1bb84':'#f1dfb4','#624535':'#81765f','#755139':'#8d856d','#a4764e':'#c5b999','#c3af88':'#c3c8b5','#ead3a6':'#eee8ce'}
for y in range(im.height):
 for x in range(im.width):
  pixel=im.getpixel((x,y))
  if pixel[3]!=255:continue
  key='#%02x%02x%02x'%pixel[:3]
  if key in colors:im.putpixel((x,y),tuple(bytes.fromhex(colors[key][1:]))+(255,))
d=ImageDraw.Draw(im)
d.rectangle((1,13,62,17),fill='#c4c7b2');d.line((2,13,61,13),fill='#f0ead1');d.line((2,17,61,17),fill='#989d88')
for x,y in [(27,14),(31,16),(39,14),(49,16),(56,14)]:d.point((x,y),fill='#a7af9a')
for x in [31,43]:
 d.rectangle((x,10,x+10,16),fill='#627c78');d.rectangle((x+1,11,x+9,15),fill='#99b4a5');d.line((x+2,12,x+8,12),fill='#d8e0c5')
d.line((41,11,41,6),fill='#b89a62',width=2);d.line((41,6,47,6),fill='#e8d19c',width=2);d.line((47,6,47,9),fill='#a89061')
for x in [12,31,50]:d.rectangle((x,22,x+3,23),fill='#c7a968');d.point((x,22),fill='#f3dfac')
for x in [26,29]:d.line((x,2,x,8),fill='#8b7960');d.ellipse((x-1,6,x+1,9),fill='#b4b9a4')
save(im,'kitchen_estate')
# Estate oak uses narrow parquet courses and small brass joint details, not random glitter.
im=Image.open(D/'floor_polished_atlas.png').convert('RGBA');tile=Image.new('RGBA',(16,16));d=ImageDraw.Draw(tile)
for row in range(4):
 y=row*4;d.rectangle((0,y,15,y+3),fill=['#98714d','#a67b51','#ad8258','#a27952'][row]);d.line((0,y,15,y),fill='#705137');d.line((0,y+1,15,y+1),fill='#c29c6e')
 joint=[3,11,7,15][row];d.line((joint,y+1,joint,y+3),fill='#78583b')
 if row%2==0:d.point((joint-1,y+2),fill='#dcc28c')
im.paste(tile.resize((32,32),Image.NEAREST),(224,0));im.save(D/'floor_estate_atlas.png')
im,d=canvas(64,56);wood(d,(1,1,30,25),90);d.rectangle((4,4,27,22),fill='#485a6c');d.rectangle((5,5,26,21),fill='#596b7e')
points=[(8,15),(12,8),(17,12),(24,7),(21,18),(14,18)]
for a,b in zip(points,points[1:]):d.line((a[0],a[1],b[0],b[1]),fill='#9aa99d')
for x,y in points:
 d.line((x-1,y,x+1,y),fill='#e1cd91');d.line((x,y-1,x,y+1),fill='#e1cd91');d.point((x,y),fill='#fae7b2')
save(im,'star_map')
im,d=canvas(64,56);d.line((16,0,16,10),fill='#8b7653',width=2);d.rectangle((13,9,19,12),fill='#b59b69')
d.polygon([(16,12),(19,17),(25,17),(21,21),(23,27),(16,24),(9,27),(11,21),(7,17),(13,17)],fill='#79674d')
d.polygon([(16,13),(18,18),(23,18),(19,21),(21,25),(16,23),(11,25),(13,21),(9,18),(14,18)],fill='#dbc38e')
d.polygon([(16,16),(18,20),(16,23),(14,20)],fill='#f4dfaa');d.point((16,19),fill='#fff0c6')
save(im,'star_lantern')

# Exterior variants use the original exact canvas/silhouette and doorway alignment.
original=Image.open(R/'assets/buildings/house.png').convert('RGBA')
for level in range(1,5):
 im=original.copy();px=im.load()
 for y in range(im.height):
  for x in range(im.width):
   rr,gg,bb,aa=px[x,y]
   if not aa:continue
   if level>=3 and y<79 and rr>gg*1.15 and gg>bb:
    if level==3:px[x,y]=(int(rr*.64),min(255,int(gg*1.04)+15),int(bb*.92)+12,aa)
    else:px[x,y]=(int(rr*.65)+8,int(gg*.90)+10,min(255,int(bb*1.50)+28),aa)
 draw=ImageDraw.Draw(im)
 if level>=2:
  for x in [39,129]:draw.line((x,92,x+28,92),fill='#e1c38e',width=2);draw.line((x,124,x+28,124),fill='#8b6548',width=2)
  for x in [24,164]:draw.line((x,85,x,143),fill='#78503c',width=2);draw.line((x+1,86,x+1,142),fill='#b68a5a')
 if level>=3:
  for x in [45,135]:
   draw.rectangle((x,119,x+20,124),fill='#725137')
   for j in range(4):draw.rectangle((x+2+j*5,116,x+4+j*5,120),fill='#819a5d');draw.point((x+3+j*5,115),fill='#d6b085')
 if level>=4:
  for x in [29,161]:
   draw.rectangle((x,101,x+4,111),fill='#6a533c');draw.rectangle((x+1,103,x+3,108),fill='#ebcc83');draw.point((x+2,104),fill='#fff1bb')
  for x,y in [(61,52),(124,49),(101,29)]:draw.line((x-2,y,x+2,y),fill='#d6c6a0');draw.line((x,y-2,x,y+2),fill='#d6c6a0')
 im.putalpha(original.getchannel('A'));im.save(D/('exterior_'+str(level)+'.png'))
print('Original home interior assets:',len(list(D.glob('*.png'))),'PNG files; no extracted reference pixels.')
