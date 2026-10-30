"""Native pixel, directional-frame and source-contract audit for ranch 0.8.2."""
from pathlib import Path
from PIL import Image
import json,hashlib,subprocess
R=Path(__file__).resolve().parents[1];folder=R/'assets/livestock/ranch082'
config=json.loads((R/'resources/presentation/world_palette.json').read_text());palette={tuple(bytes.fromhex(c)) for ramp in config['ramps'].values() for c in ramp}
report={'palette':config['name'],'grid':32,'direction_rows':['down','left','right','up'],'actions':['walk','graze','rest'],'frames_per_direction':4,'assets':[],'external_new_assets':False}
for name,size in [('chicken',(32,32)),('duck',(32,32)),('cow',(48,40)),('sheep',(40,36))]:
 p=folder/(name+'.png');im=Image.open(p).convert('RGBA');assert im.size==(size[0]*4,size[1]*12)
 for row in range(12):
  for col in range(4): assert im.crop((col*size[0],row*size[1],(col+1)*size[0],(row+1)*size[1])).getbbox()
 assert len({hashlib.sha256(im.crop((0,row*size[1],size[0],(row+1)*size[1])).tobytes()).hexdigest() for row in range(4)})==4
 assert im.crop((0,0,*size)).tobytes()!=im.crop((size[0],0,size[0]*2,size[1])).tobytes()
for p in sorted(folder.glob('*.png')):
 im=Image.open(p).convert('RGBA');opaque=[v for v in im.getdata() if v[3]]
 assert opaque and all(v[3]==255 and v[:3] in palette for v in opaque),p
 report['assets'].append({'file':str(p.relative_to(R)),'size':list(im.size),'native_pixels':True,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
assert Image.open(folder/'duck_egg.png').size==(32,32)
assert Image.open(folder/'salted_duck_egg.png').size==(32,32)
assert (folder/'nest_empty.png').read_bytes()!=(folder/'nest.png').read_bytes()
protected=['resources/fishing/fishing.json','resources/seasons/climate.json','resources/story/marriage_preparation.json','scripts/time/game_clock.gd','resources/crops/carrot.tres','resources/crops/potato.tres','resources/crops/wheat.tres']
records=[]
for name in protected:
 p=R/name
 if not p.exists():continue
 old=subprocess.check_output(['git','show','244c379:'+name],cwd=R)
 assert old==p.read_bytes(),name+' changed outside ranch scope'
 records.append({'file':name,'sha256':hashlib.sha256(old).hexdigest(),'unchanged_since':'244c379'})
report['protected_rules']=records
(R/'docs/ranch082/assets.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('RANCH082 ASSET AUDIT: PASS;',len(report['assets']),'native assets;',len(records),'unchanged rule definitions')
