"""整理实际Godot窗口截图；Pillow仅负责并排对照，不绘制或伪造游戏界面。"""
from pathlib import Path
import json, shutil
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/ui05'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').touch()
font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),20)
manifest={'baseline_commit':'2a48963','runtime':'Godot 4.3 Linux Xvfb/Mesa','android_device_tested':False,'captures':[]}
for phase in ['before','after','extra']:
 data=json.loads((ROOT/f'builds/ui05-{phase}-manifest.json').read_text())
 if data['failures']: raise RuntimeError(f'{phase}捕获失败')
 for item in data['captures']:
  selected=item['resolution']==[1280,720] or (phase!='before' and item['name'] in ['hud','dialogue'])
  if not selected: continue
  source=ROOT/item['path'].removeprefix('res://')
  target=OUT/f"{phase}-{item['resolution'][0]}-{item['name']}.png"
  shutil.copyfile(source,target)
  manifest['captures'].append({k:v for k,v in item.items() if k in ['name','resolution','panel','panel_inside_safe_area','saved','hud_area_fraction','hud_union_area'] }|{'file':str(target.relative_to(ROOT)),'phase':phase})
for label in ['hud','hotbar-expanded','inventory','dialogue','shop','quests','xiaojing','kitchen','fishpen']:
 before=Image.open(OUT/f'before-1280-{label}.png').convert('RGB')
 after=Image.open(OUT/f'after-1280-{label}.png').convert('RGB')
 comparison=Image.new('RGB',(2560,756),'#35291f')
 comparison.paste(before,(0,36));comparison.paste(after,(1280,36))
 draw=ImageDraw.Draw(comparison)
 draw.text((16,5),'UI04 · 2a48963 · 改版前',font=font,fill='#f4e7cd')
 draw.text((1296,5),'UI05 · 实际 Godot 窗口 · 改版后',font=font,fill='#f4e7cd')
 comparison.save(OUT/f'compare-{label}.png')
for name in ['follow','native_drag','return','home']:
 shutil.copyfile(ROOT/f'builds/ui05-camera-{name}.png',OUT/f'camera-{name}.png')
(OUT/'screenshots.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(f'{len(manifest["captures"])}张实际界面、9张前后对照、4张相机画面已整理至docs/ui05')

for original,label in [
 ("layout-1560x720-target48-inventory-grid.png","adapt-19_5-9-inventory.png"),
 ("layout-1600x720-target48-inventory-grid.png","adapt-20-9-inventory.png"),
 ("layout-1280x960-target48-inventory-grid.png","adapt-tablet-inventory.png"),
 ("layout-1600x720-target96-safe64-dialogue-bottom.png","adapt-target96-dialogue.png"),
 ("layout-1280x720-target48-dialogue-choices.png","dialogue-choices.png")]:
 shutil.copyfile(ROOT/"builds/UI05"/original,OUT/label)
