"""Check native canvas contracts, actual stage images, palette and business-data isolation."""
from pathlib import Path
from PIL import Image
import argparse,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--sample',action='store_true');p.add_argument('--allow-balance',action='store_true');args=p.parse_args()
palette=json.loads((ROOT/'resources/presentation/world_palette.json').read_text())
colors={tuple(bytes.fromhex(c)) for ramp in palette['ramps'].values() for c in ramp}
data=json.loads((ROOT/'resources/harvest/harvest.json').read_text())
ids=['strawberry'] if args.sample else list(data['crops'])+['carrot','potato','wheat']
records=[];seen=set()
def image(path,size):
 im=Image.open(ROOT/path).convert('RGBA');assert im.size==size,(path,im.size,size);assert im.getbbox(),path
 assert all(p[:3] in colors for p in im.getdata() if p[3]),'Palette mismatch: '+path
 if path not in seen:records.append({'path':path,'size':list(size),'sha256':hashlib.sha256((ROOT/path).read_bytes()).hexdigest()});seen.add(path)
 return im
for id in ids:
 image(f'assets/harvest/items/{id}.png',(32,32));image(f'assets/harvest/items/{id}_seed.png',(32,32))
 if id in data['crops']:
  im=image(f'assets/harvest/crops/{id}.png',(128,40));stages=[im.crop((i*32,0,i*32+32,40)) for i in range(4)]
  assert len({stage.tobytes() for stage in stages})==4,id+' ambiguous growth frames'
  assert all(stage.getbbox() and stage.getbbox()[0]>=1 and stage.getbbox()[1]>=1 and stage.getbbox()[2]<=31 and stage.getbbox()[3]<=38 for stage in stages),id+' clipped stage'
for id in (['bread','mayonnaise'] if args.sample else data['items']):image(f'assets/harvest/items/{id}.png',(32,32))
for id in (['jam_pot'] if args.sample else data['stations']):image(f'assets/harvest/stations/{id}.png',(32,48))
image('assets/kitchen/flour.png',(32,32))
if not args.sample:
 image('assets/crops/crops.png',(128,120))
 animation=json.loads((ROOT/'resources/presentation/workshop_visuals.json').read_text());sheet=image(animation['texture'].removeprefix('res://'),(128,560))
 assert set(animation['stations'])==set(data['stations'])
 for id,row in animation['stations'].items():
  frames=[sheet.crop((i*32,row['row']*56,(i+1)*32,(row['row']+1)*56)) for i in range(4)]
  assert len({im.tobytes() for im in frames})>=2,id+' missing visual motion'
  assert row['padding_top']==8 and row['frame_size']==[32,56] and row['fps']<=6
 for path in (ROOT/'assets/harvest/orchard').glob('*.png'): image(path.relative_to(ROOT).as_posix(),(96,96))
 for id in ['egg','milk','wool','hay']:image(f'assets/livestock/{id}.png',(32,32))
 for id in ['chicken','cow','sheep']:image(f'assets/livestock/{id}.png',(64,32))
 for path,rect in json.loads((ROOT/'tools/art_source/agriculture080.json').read_text()).items():image(path,tuple(rect[2:]))
 image('assets/housing/wool_rug.png',(64,64));image('assets/housing/cotton_chair.png',(32,48))
if not args.allow_balance:
 before=json.loads((ROOT/'docs/quality081/economy-before.json').read_text())
 for path,value in before.items():assert json.loads((ROOT/'resources'/f'{path}.json').read_text())==value,'Art changed business data: '+path
report={'phase':'sample' if args.sample else 'full','resources':len(records),'native_sizes':'passed','palette':'passed','distinct_stages':'passed','business_data_unchanged':not args.allow_balance,'files':records}
(ROOT/'docs/quality081'/('sample-assets.json' if args.sample else 'assets.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('QUALITY081 ART PASS:',len(records),'native resources')
