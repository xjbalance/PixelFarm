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

# Exterior finish matches the cream-and-oak interior, preserving the exact original alpha.
# Recolor/draw on native integer pixels; walls, roof silhouette and doorstep never move.
original=Image.open(R/'assets/buildings/house.png').convert('RGBA')
roof_palettes=[('#aa7e59','#c59b6e','#896344'),('#9d7b56','#c2a071','#7e603f'),('#7d8764','#a4ad80','#5f6e4e'),('#6f805f','#9eae7d','#52684b')]
for level,(roof_base,roof_light,roof_dark) in enumerate(roof_palettes,1):
 im=original.resize((96,84),Image.NEAREST);pixels=im.load()
 recolor={
  '#b76449':roof_base,'#cf8058':roof_light,'#995039':roof_dark,
  '#e0c58b':'#eadebd','#c9a675':'#cdb48b',
  '#815b46':'#86633f','#946b48':'#b48b59','#805a42':'#947047',
  '#a17c59':'#b69a73','#a49375':'#c0b397','#b19b75':'#d0b997',
  '#a18157':'#a27d50','#c4a271':'#dfbd88','#78583f':'#8a653f',
  '#704c3e':'#73513a','#e0aa6e':'#dbc193',
  '#758267':'#8d9c78','#4f6e59':'#667a5b',
  '#89bcc0':'#a8c6ba','#d7d9ab':'#e6e0bf','#cae1cb':'#e8ebd2',
  '#776353':'#8b7b63','#a28b6b':'#c1ac83'
 }
 lookup={tuple(bytes.fromhex(key[1:])):tuple(bytes.fromhex(value[1:])) for key,value in recolor.items()}
 for y in range(84):
  for x in range(96):
   color=pixels[x,y]
   if color[3]==255 and color[:3] in lookup:pixels[x,y]=lookup[color[:3]]+(255,)
 draw=ImageDraw.Draw(im)
 # Limewash is framed by real timber uprights; the house remains the same size.
 for x in [14,80]:
  draw.line((x,41,x,64),fill='#8b6945');draw.line((x+1,42,x+1,63),fill='#d1ac77')
 for x in [17,77]:
  draw.polygon([(x,40),(x+3,40),(x+3,41),(x+1,44),(x,44)],fill='#a68153')
  draw.line((x,40,x+3,40),fill='#d3af7b')
 for x in [41,57]:draw.line((x,49,x,73),fill='#86613e')
 draw.line((43,49,55,49),fill='#d6b680');draw.line((44,51,44,70),fill='#c9a371')
 draw.rectangle((51,60,53,62),fill='#d9bd86');draw.point((52,61),fill='#f3dfad')
 # Four stages add joinery, a few plants and warm light, without purple repainting.
 if level>=2:
  for x in [19,63]:
   draw.line((x,42,x+16,42),fill='#ddc293');draw.line((x,61,x+16,61),fill='#9c794f')
   draw.rectangle((x+1,59,x+15,61),fill='#af8a59');draw.line((x+2,59,x+14,59),fill='#ddbd88')
 if level>=3:
  for x in [23,67]:
   for offset in [0,5,9]:
    draw.rectangle((x+offset,56,x+offset+2,58),fill='#7b9467');draw.point((x+offset+1,55),fill='#cad2a2')
   draw.point((x+5,56),fill='#e0c093')
 if level>=4:
  for x in [16,79]:
   draw.line((x+1,46,x+1,49),fill='#896c45')
   draw.rectangle((x,49,x+2,54),fill='#9f8353');draw.rectangle((x,50,x+2,52),fill='#ead399');draw.point((x+1,51),fill='#fff0bf')
  for x,y in [(33,22),(62,23)]:
   draw.point((x,y-1),fill='#c5cda0');draw.line((x-1,y,x+1,y),fill='#c5cda0');draw.point((x,y+1),fill='#c5cda0');draw.point((x,y),fill='#eee6b9')
 im=im.resize(original.size,Image.NEAREST);im.putalpha(original.getchannel('A'));im.save(D/('exterior_'+str(level)+'.png'))
print('Original home interior assets:',len(list(D.glob('*.png'))),'PNG files; no extracted reference pixels.')

# Warm-country remaster: native two-pixel silhouettes, linen cloth and restrained oak.
# These original pixels are drawn from geometry, never sampled from the references.
CREAM='#eee2c2'; HONEY='#bb8859'; MOSS='#6e8264'; SEAM='#a7b38a'
def rounded(d,box,fill,outline=O,radius=2,width=1):
 d.rounded_rectangle(box,radius=radius,fill=fill,outline=outline,width=width)
def textile(d,box,base=MOSS):
 x,y,xx,yy=box;rounded(d,box,base,'#4c624d',2)
 d.line((x+2,y+1,xx-2,y+1),fill='#b1bd91');d.line((x+2,yy-1,xx-2,yy-1),fill='#526950')
 for px,py in [(x+4,y+5),(xx-5,y+9),(x+9,yy-5)]:d.line((px,py,px+2,py),fill='#92a27d')
def pillow(d,box,color=CREAM):
 x,y,xx,yy=box;rounded(d,box,'#c4bea0','#839077',2);rounded(d,(x+1,y,xx-1,yy-1),color,'#d3cfaf',2)
 d.line((x+3,y+2,xx-3,y+2),fill='#fff1d2');d.line((x+2,yy-2,xx-2,yy-2),fill='#b9b99a')
# Quiet staggered planks: eight column tiles, long grain marks on only a few boards.
for name,palette in [('floor_oak_atlas',['#a47d54','#ac8359','#b38a60','#ad845a']),('floor_polished_atlas',['#ad865d','#b68e63','#bd9669','#b78f64']),('floor_estate_atlas',['#b28a5f','#ba9266','#c09a6e','#b68e63']),('floor_pale_atlas',['#bda17b','#c4aa85','#cab18e','#c3a681'])]:
 atlas=Image.new('RGBA',(256,32))
 for variant in range(8):
  tile=Image.new('RGBA',(16,16));d=ImageDraw.Draw(tile)
  for row in range(2):
   y=row*8;d.rectangle((0,y,15,y+7),fill=palette[(variant+row)%len(palette)])
   d.line((0,y,15,y),fill='#876444' if name!='floor_pale_atlas' else '#a08864');d.line((0,y+1,15,y+1),fill='#c7a477' if name!='floor_pale_atlas' else '#ddc5a1')
   if (variant+row)%4==0:
    joint=4 if variant<4 else 12;d.line((joint,y+1,joint,y+7),fill='#926e49')
   if variant in [1,5]:d.line((3,y+5,11,y+5),fill=palette[(variant+row+1)%4])
  atlas.paste(tile.resize((32,32),Image.NEAREST),(variant*32,0))
 atlas.save(D/(name+'.png'))
# Cream limewash above short oak wainscot, with cutaway wall/door geometry unchanged.
for level in range(1,5):
 im,d=canvas(640,464)
 d.rectangle((0,0,319,39),fill='#4e3d30');d.rectangle((7,6,312,37),fill='#e3d1ac')
 d.rectangle((9,8,310,25),fill='#ebddbd')
 for x,y in [(35,13),(87,19),(132,11),(206,18),(270,13)]:d.line((x,y,x+3,y),fill='#e1d1ae')
 d.rectangle((9,26,310,36),fill='#b58e62')
 for x in range(11,311,14):
  d.line((x,27,x,35),fill='#9d764e');d.line((x+1,27,x+1,34),fill='#c8a576')
 for y,color in [(3,'#715035'),(5,'#bd966a'),(25,'#b38c60'),(26,'#d8b98b'),(37,'#6b4f35'),(38,'#ab8055')]:d.line((3,y,316,y),fill=color,width=2)
 for x in [2,14,304,316]:
  d.rectangle((x,4,x+3,43),fill='#6e5036');d.line((x+1,6,x+1,39),fill='#bb9563')
 for x in [0,304]:
  spans=[(40,215)] if x!=0 or level==1 else [(40,135),(184,215)]
  for a,b in spans:
   d.rectangle((x,a,x+15,b),fill='#4e3c2d');d.rectangle((x+2,a,x+11,b),fill='#a48258');d.line((x+3,a,x+3,b),fill='#cfad7a')
 for a,b in [(0,145),(175,319)]:
  d.rectangle((a,216,b,231),fill='#4e3b2d');d.rectangle((a+2,217,b-2,226),fill='#b28b5b');d.line((a+2,218,b-2,218),fill='#dbb987')
 d.rectangle((146,215,174,231),fill='#5b4331')
 for y in [218,222,226,230]:d.rectangle((147,y,173,y+2),fill='#bb945f');d.line((148,y,172,y),fill='#e6c390')
 save(im,'walls_'+str(level))
# Bed: curved headboard, two separate piped pillows and a weighted quilt edge.
for quilt in [False,True]:
 im,d=canvas(96,128);shadow(d,(2,6,43,55))
 rounded(d,(3,2,44,60),'#a7764d',O,4);rounded(d,(4,1,43,18),'#a97c50',O,4)
 rounded(d,(8,4,39,15),'#c49a67','#815a3c',3);d.line((10,5,37,5),fill='#e1be87');d.line((11,12,36,12),fill='#ae8255')
 rounded(d,(5,17,42,59),'#c8bc98','#70553b',3);d.line((6,19,41,19),fill='#f3e4bf')
 pillow(d,(8,18,22,29));pillow(d,(25,18,39,29),'#e4e3c5')
 textile(d,(6,31,41,58),'#687d61' if not quilt else '#76866a')
 rounded(d,(6,30,41,35),'#bdc49a','#99aa80',2);d.line((8,31,39,31),fill='#e0dfba')
 if quilt:
  for x,y in [(13,40),(29,40),(21,49),(36,51)]:
   d.polygon([(x,y-3),(x+3,y),(x,y+3),(x-3,y)],fill='#b9bb91');d.point((x,y),fill='#dfd6ae')
 else:
  d.line((11,37,11,54),fill='#879a75');d.line((36,38,36,55),fill='#566e54');d.line((12,55,33,55),fill='#9baa82')
 rounded(d,(4,56,43,61),'#b68b58','#674b34',2);d.line((7,57,40,57),fill='#d9b47c')
 for x in [3,41]:
  d.rectangle((x,9,x+3,62),fill='#765337');d.line((x+1,11,x+1,60),fill='#c59b62');rounded(d,(x-1,6,x+4,10),'#d9b17b','#7e5b3a',2)
 save(im,'bed_quilt' if quilt else 'bed')
# Rounded upholstery and individual cushion/arm shapes at the unchanged native size.
for name,base in [('sofa','#7e906d'),('sofa_cottage','#71876b'),('sofa_estate','#617e71')]:
 im,d=canvas(88,56);shadow(d,(1,10,42,15));rounded(d,(2,8,41,25),'#75563b',O,3)
 rounded(d,(3,2,40,20),'#4e6652',O,4);rounded(d,(5,3,38,16),base,'#92a381',3)
 d.line((8,4,35,4),fill='#b9c49b');d.line((21,6,21,14),fill='#617757')
 for x in [6,23]:
  rounded(d,(x,15,x+15,23),'#91a27f','#5a7258',2);d.line((x+2,16,x+13,16),fill='#bfca9e');d.line((x+2,22,x+13,22),fill='#6c835f')
 for x in [0,38]:
  rounded(d,(x,10,x+5,25),'#78916d','#47624d',2);d.line((x+1,11,x+4,11),fill='#c0c69f')
 pillow(d,(7,6,14,14));pillow(d,(29,6,36,14),'#c5b48c')
 for x in [5,36]:d.rectangle((x,25,x+2,27),fill='#5c4430')
 if name=='sofa_estate':d.line((16,8,19,11),fill='#dcc69b');d.line((16,11,19,8),fill='#dcc69b')
 save(im,name)
# Dressers and bookcase: timber framing, varied ceramics, calm dark shelf recesses.
im,d=canvas(136,80);shadow(d,(3,8,62,29));wood(d,(3,4,62,32),74)
rounded(d,(2,2,65,7),'#c49b68','#725137',2);d.line((4,3,62,3),fill='#e3bf89')
for yy in [9,19]:
 d.rectangle((7,yy,60,yy+7),fill='#5d4b38')
 for j,x in enumerate(range(10,57,9)):
  if yy==9:
   d.ellipse((x,yy+1,x+5,yy+5),fill=['#e5ddbb','#9bae98','#c9b696'][j%3]);d.line((x+1,yy+1,x+4,yy+1),fill='#fff0cc')
  else:book(d,x,yy+1,5,5,['#6d8471','#b28c69','#94957b'][j%3])
 d.line((7,yy+7,60,yy+7),fill='#d1aa74')
for x in [7,34]:
 rounded(d,(x,29,x+25,35),'#ac8054','#725039',1);d.line((x+2,30,x+23,30),fill='#c99f69');d.rectangle((x+11,31,x+13,32),fill='#ead19a')
for x in [5,60]:d.rectangle((x,35,x+2,39),fill='#62472f')
d.ellipse((48,0,57,4),fill='#dcd3b2');d.ellipse((50,0,55,2),fill='#fbedd1');save(im,'dresser')
im,d=canvas(64,48);shadow(d,(2,3,28,19));wood(d,(1,0,30,22),83)
for yy in [3,12]:
 d.rectangle((4,yy,27,yy+7),fill='#574934')
 for i,x in enumerate(range(5,27,4)):
  height=5 if i%2 else 6;d.rectangle((x,yy+7-height,x+2,yy+6),fill=['#6d8c78','#a98265','#c0ad7e','#8d9490'][i%4]);d.point((x+1,yy+2),fill='#dfcf9f')
 d.line((3,yy+7,28,yy+7),fill='#caa371')
save(im,'bookcase')
# Farmhouse table with soft corners and linen runner; carved chairs keep their footprints.
im,d=canvas(120,84);shadow(d,(5,13,50,26))
for x in [10,46]:d.rectangle((x,24,x+3,40),fill='#6b4c33');d.line((x+1,27,x+1,38),fill='#b38958')
rounded(d,(5,5,54,34),'#805b3b',O,4);rounded(d,(6,4,53,31),'#b58a59','#785337',4)
for yy in [6,14,23,30]:d.line((10,yy,49,yy),fill='#c59b69' if yy in [6,23] else '#9b7049')
d.rectangle((24,5,35,32),fill='#b7c09a');d.line((25,6,25,31),fill='#e5ddbb');d.line((34,6,34,31),fill='#7d9672')
d.ellipse((20,12,39,25),fill='#73543a');d.ellipse((21,12,38,23),fill='#d5b77d');d.ellipse((23,14,36,21),fill='#738254')
for x,y,c in [(26,16,'#d3a05d'),(31,16,'#b77250'),(28,19,'#e5c37e')]:d.ellipse((x,y,x+3,y+3),fill=c)
d.ellipse((42,8,49,14),fill='#e5ddbf');d.ellipse((43,9,48,12),fill='#88745a');save(im,'dining_table')
for name,flip in [('chair_left',False),('chair_right',True)]:
 im,d=canvas(28,48);shadow(d,(1,13,12,9));rounded(d,(2,1,11,18),'#a17b50','#604a33',2)
 rounded(d,(4,4,9,14),'#82926e','#637953',1);d.line((5,5,8,5),fill='#c4c79c')
 rounded(d,(1,15,12,20),'#a2ae87','#6d784e',2)
 for x in [2,10]:d.rectangle((x,20,x+1,23),fill='#62452f')
 if flip:im=im.transpose(Image.FLIP_LEFT_RIGHT)
 save(im,name)
# Cream cabinetry and warm grey limestone rather than the old all-brown slab.
for estate in [False,True]:
 im,d=canvas(128,72);shadow(d,(1,10,62,24));d.rectangle((1,1,62,14),fill='#d6d5b9')
 for y in [2,8]:
  d.line((2,y,61,y),fill='#eee4c9')
  for x in range(5+(3 if y==8 else 0),61,10):d.line((x,y,x,y+5),fill='#c0c1a9')
 rounded(d,(2,16,61,33),'#d2c29e','#84705a',1)
 for x in [5,24,43]:
  rounded(d,(x,20,x+15,30),'#e3d6b2','#ad9a7a',1);d.line((x+2,21,x+13,21),fill='#f7e9c8');d.rectangle((x+6,23,x+9,24),fill='#ad8a53')
 rounded(d,(1,13,62,18),'#c3c5b0','#8e9787',1);d.line((2,13,61,13),fill='#f3ebd4')
 d.rectangle((4,9,24,15),fill='#59605a');d.ellipse((8,8,17,14),fill='#3d4942');d.ellipse((9,8,16,12),fill='#7d8a7b');d.line((17,10,21,8),fill='#3c4840',width=2)
 rounded(d,(31,10,52,16),'#778e83','#566f67',2);d.rectangle((33,11,50,14),fill='#a9c0ad');d.line((34,11,49,11),fill='#d9e2c8')
 d.line((41,10,41,5),fill='#b79867',width=2);d.line((41,5,46,5),fill='#e7c993',width=2);d.line((46,5,46,8),fill='#927b56')
 d.rectangle((7,23,17,29),fill='#53594d');d.rectangle((9,24,15,27),fill='#b98a51');d.line((8,22,16,22),fill='#d9c79e')
 d.ellipse((55,7,61,12),fill='#ba9b6e');d.rectangle((56,4,60,9),fill='#d7c5a0');d.ellipse((56,3,60,5),fill='#84966f')
 if estate:
  for x in [27,29]:d.line((x,2,x,7),fill='#9d8967');d.ellipse((x-1,6,x+1,9),fill='#c3c7af')
 save(im,'kitchen_estate' if estate else 'kitchen')
# Less blanket coverage: inset woven rugs retain original transparent canvas dimensions.
def country_rug(width,height,name,base='#819275',accent='#c9b88b',inset=8):
 im,d=canvas(width,height);w=im.width;h=im.height;left=min(inset,max(1,w//6));top=min(inset,max(1,h//6))
 rounded(d,(left,top,w-left-1,h-top-1),'#7a7055','#6c634e',3)
 rounded(d,(left+1,top+1,w-left-2,h-top-2),accent,accent,3)
 rounded(d,(left+3,top+3,w-left-4,h-top-4),base,base,2)
 d.rectangle((left+5,top+5,w-left-6,h-top-6),outline=accent)
 for x in range(left+6,w-left-6,6):d.line((x,top-1,x,top),fill='#d9c8a3');d.line((x,h-top-1,x,h-top),fill='#d9c8a3')
 cx=w//2;cy=h//2
 for ox,oy in [(-9,-3),(9,3),(0,0)]:
  d.line((cx+ox,cy+oy-3,cx+ox,cy+oy+3),fill=accent);d.line((cx+ox-2,cy+oy-1,cx+ox+2,cy+oy+1),fill=accent)
 save(im,name)
country_rug(240,126,'main_rug',inset=17);country_rug(176,104,'dining_rug','#a28d70',inset=9)
country_rug(96,144,'bed_rug','#a18e78',inset=5);country_rug(80,104,'study_rug_2',inset=5)
country_rug(176,176,'study_rug','#81907a',inset=19);country_rug(224,224,'study_rug_4','#758d7a',inset=25)
# Writing surfaces and storage add a notebook, rounded drawer fronts and woven baskets.
im,d=canvas(88,56);shadow(d,(2,11,39,14));wood(d,(4,6,36,16),132)
rounded(d,(2,4,41,18),'#be9666','#705136',2);d.line((4,5,39,5),fill='#dfbd89')
book(d,7,8,11,7,'#7f987a');d.rectangle((22,7,32,14),fill='#ede1bb')
for y in [9,11,13]:d.line((24,y,30,y),fill='#a6a486')
d.ellipse((34,7,38,11),fill='#7b664d');d.line((36,7,39,2),fill='#ded6b7');d.line((38,4,40,3),fill='#b0bda0')
for x in [5,37]:d.rectangle((x,20,x+2,27),fill='#715136');d.line((x+1,21,x+1,25),fill='#bd9965')
rounded(d,(7,19,20,23),'#a17b50','#7c593d',1);d.rectangle((12,20,14,21),fill='#e1c593');save(im,'mail_desk')
for level,width in [(2,104),(3,192),(4,256)]:
 im,d=canvas(width,64);w=width//2;shadow(d,(1,12,w-2,17))
 for x in [4,w-8]:d.rectangle((x,21,x+3,31),fill='#765339');d.line((x+1,23,x+1,29),fill='#bc9465')
 wood(d,(3,12,w-6,13),level*27);rounded(d,(1,8,w-2,20),'#bd9665','#735137',2);d.line((4,9,w-5,9),fill='#dfbd8a')
 book(d,7,10,12,7,'#829579');book(d,22,11,10,6,'#a78266')
 if w>70:
  d.rectangle((w//2-10,10,w//2+9,18),fill='#ede0bb')
  for y in [12,15,17]:d.line((w//2-7,y,w//2+6,y),fill='#a4a182')
 for x in [w-17,w-9]:d.rectangle((x,8,x+3,12),fill='#b5a480');d.ellipse((x,7,x+3,9),fill='#e7dcbc')
 for x in [7,w-25]:
  rounded(d,(x,22,x+17,27),'#ad8657','#7a583c',1);d.rectangle((x+8,23,x+10,24),fill='#dfc18a')
 save(im,'study_desk_'+str(level))
im,d=canvas(32,64);shadow(d,(1,10,14,19));rounded(d,(1,7,14,29),'#a78355','#6b4e34',2)
rounded(d,(0,5,15,11),'#c29c69','#765338',2);d.line((2,6,13,6),fill='#e3c28c')
for y in [13,21]:
 rounded(d,(3,y,12,y+6),'#b99767','#87623f',1);d.line((4,y+1,11,y+1),fill='#d2b17c');d.rectangle((7,y+3,9,y+3),fill='#e3cb96')
for x in [2,12]:d.rectangle((x,28,x+1,31),fill='#684b34')
save(im,'storage_slim')
# Side rooms receive the same cream limewash and oak dado, without changing any opening.
for level,w,h in [(2,128,160),(3,224,288),(4,288,352)]:
 im,d=canvas(w+24,h+60);ww=im.width;hh=im.height
 d.rectangle((0,0,ww-1,23),fill='#5a4230');d.rectangle((5,5,ww-7,16),fill='#e8d9b7');d.rectangle((5,17,ww-7,22),fill='#b68f61')
 for x in range(8,ww-7,14):d.line((x,18,x,22),fill='#97724a');d.line((x+1,18,x+1,21),fill='#c9a979')
 for y,color in [(2,'#9b744d'),(4,'#d2ae7d'),(16,'#c4a06d'),(22,'#7b593b')]:d.line((2,y,ww-3,y),fill=color,width=2)
 d.rectangle((0,22,5,hh-1),fill='#5b4230');d.rectangle((2,24,4,hh-4),fill='#bc9663')
 d.rectangle((4,hh-7,ww-1,hh-1),fill='#5b4430');d.rectangle((5,hh-6,ww-1,hh-3),fill='#b78f5c');d.line((5,hh-6,ww-1,hh-6),fill='#dfbf8d')
 save(im,'extension_walls_'+str(level))
# Placed furniture is drawn at its true footprint; no runtime stretching.
im,d=canvas(32,64);shadow(d,(1,4,13,27));rounded(d,(1,1,14,30),'#ad8454','#684b32',2);rounded(d,(3,3,12,10),'#c6a06c','#8b6642',2)
pillow(d,(3,11,12,16));textile(d,(3,17,12,28));d.line((4,18,11,18),fill='#c4c7a0');d.rectangle((2,28,13,30),fill='#b89360');save(im,'placeable_bed')
im,d=canvas(64,32);shadow(d,(1,5,30,10));rounded(d,(1,1,30,12),'#b78d5c','#735236',2);d.line((3,2,28,2),fill='#dfbd88');d.rectangle((14,2,19,12),fill='#aeb891')
for x in [3,27]:d.rectangle((x,12,x+1,15),fill='#674b34')
d.ellipse((13,4,20,9),fill='#d4bc86');d.ellipse((15,5,18,7),fill='#8a956b');save(im,'placeable_table')
im,d=canvas(32,32);shadow(d,(3,6,10,9));rounded(d,(4,1,11,11),'#b08a59','#6d5036',2);d.rectangle((6,3,9,8),fill='#829871');rounded(d,(2,9,13,13),'#b1bd90','#6c7957',2)
for x in [3,11]:d.rectangle((x,13,x+1,15),fill='#705139')
save(im,'placeable_chair')
im,d=canvas(32,32);shadow(d,(1,5,14,10));rounded(d,(1,3,14,14),'#b18a58','#77573b',1);d.rectangle((3,6,7,12),fill='#c6a06c');d.rectangle((8,6,12,12),fill='#c6a06c');d.line((3,7,6,7),fill='#e1be87');d.rectangle((6,9,9,9),fill='#eed3a2');d.line((1,3,14,3),fill='#e0bd89');save(im,'placeable_cabinet')
country_rug(64,64,'placeable_rug',inset=1)
im,d=canvas(32,32);d.ellipse((4,13,11,15),fill='#886943');d.line((8,6,8,13),fill='#a18053');d.polygon([(3,6),(5,1),(11,1),(13,6),(11,8),(5,8)],fill='#e5d7b2');d.line((5,2,11,2),fill='#fff1d0');d.line((4,7,12,7),fill='#b8ae86');save(im,'placeable_lamp')
im,d=canvas(32,32);d.polygon([(5,11),(11,11),(10,15),(6,15)],fill='#b48a61');d.rectangle((4,10,12,11),fill='#d1ab7b')
for x,y in [(3,7),(8,3),(13,6),(6,8)]:
 d.line((8,10,x,y),fill='#576e46');d.ellipse((x-2,y-2,x+1,y+1),fill='#829b64');d.point((x-1,y-1),fill='#a9b67e')
save(im,'placeable_plant')
im,d=canvas(64,32);wood(d,(2,3,28,9),17);d.line((3,4,28,4),fill='#dfbd8a');d.rectangle((15,4,24,9),fill='#ede2bf');d.line((17,6,22,6),fill='#9ba38a');book(d,5,5,7,4,'#7d9676')
for x in [3,27]:d.rectangle((x,12,x+1,15),fill='#715037')
save(im,'placeable_spouse_desk')
print('Warm-country remaster complete; native crisp furnishings and eight floor variants.')
