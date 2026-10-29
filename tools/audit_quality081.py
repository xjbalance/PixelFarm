"""Read actual runtime art/data before editing; keep a reproducible 0.8.0 audit."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,collections
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/quality081';OUT.mkdir(parents=True,exist_ok=True)
refs=['assets/crops/crops.png','assets/harvest/crops/strawberry.png','assets/harvest/crops/corn.png','assets/kitchen/flour.png','assets/kitchen/potato_bread.png','assets/harvest/items/bread.png','assets/livestock/egg.png','assets/livestock/milk.png','assets/livestock/wool.png','assets/livestock/chicken.png','assets/livestock/cow.png','assets/livestock/sheep.png','assets/harvest/stations/mill.png','assets/harvest/stations/jam_pot.png','assets/world_scheme_c/bright/sprites/picnic_table.png','assets/world_scheme_c/bright/sprites/farmhouse.png','assets/housing/interior/kitchen.png','assets/characters/scheme_c/player_male/compact_32x48/spritesheet.png','assets/characters/linya.png','assets/characters/zhou.png','assets/characters/ahe.png']
records=[];contact=Image.new('RGB',(1024,math_height:=((len(refs)+3)//4)*180),'#f4ead1');draw=ImageDraw.Draw(contact)
for i,name in enumerate(refs):
 im=Image.open(ROOT/name).convert('RGBA');opaque=[p[:3] for p in im.getdata() if p[3]>0]
 colors=collections.Counter(opaque)
 records.append({'path':name,'size':list(im.size),'sha256':hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),'opaque_colors':len(colors),'dominant':['#%02x%02x%02x'%c for c,_ in colors.most_common(8)]})
 scale=max(1,min(3,220//im.width,140//im.height));preview=im.resize((im.width*scale,im.height*scale),Image.NEAREST)
 if preview.width>230 or preview.height>145:preview.thumbnail((230,145),Image.NEAREST)
 x=(i%4)*256;y=(i//4)*180;contact.paste(preview,(x+10,y+4),preview);draw.text((x+10,y+152),name.split('/')[-1],fill='#343e37')
contact.save(OUT/'art-baseline-contact.png')
(OUT/'art-baseline.json').write_text(json.dumps({'base_commit':'14287b5','references':records},ensure_ascii=False,indent=2)+'\n')
economic={}
for name in ['harvest/harvest','kitchen/kitchen','livestock/livestock','aquaculture/fish','seasons/economy']:
 economic[name]=json.loads((ROOT/'resources'/f'{name}.json').read_text())
(OUT/'economy-before.json').write_text(json.dumps(economic,ensure_ascii=False,indent=2)+'\n')
print('Read',len(records),'existing art resources; copied current economic definitions')
