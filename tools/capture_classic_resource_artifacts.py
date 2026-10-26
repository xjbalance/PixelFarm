"""整理经典布局与丰饶森林的实际Godot窗口帧；Pillow仅拼接对照。"""
from pathlib import Path
import json,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/classic-resources'
OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
classic=json.loads((ROOT/'builds/ui05-classic-manifest.json').read_text())
rich=json.loads((ROOT/'builds/resource-rich-render-evidence.json').read_text())
if classic['failures'] or rich['failures']:raise SystemExit('截图或窗口仍有失败')
frames=[]
for item in classic['captures']:
 if item['resolution']!=[1280,720] and item['name'] not in ['hud','dialogue']:continue
 source=ROOT/item['path'].removeprefix('res://');name=f"classic-{item['resolution'][0]}-{item['name']}.png"
 shutil.copyfile(source,OUT/name);frames.append({'name':item['name'],'file':str((OUT/name).relative_to(ROOT)),'resolution':item['resolution'],'panel':item['panel'],'safe':item['panel_inside_safe_area']})
for item in rich['captures']:
 source=ROOT/item['path'].removeprefix('res://');name=item['name']+'.png';shutil.copyfile(source,OUT/name)
 frames.append({**item,'file':str((OUT/name).relative_to(ROOT))})
font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),20)
for kind in ['hud','inventory','dialogue','shop','quests']:
 before=ROOT/f'docs/ui05/after-1280-{kind}.png';after=OUT/f'classic-1280-{kind}.png'
 comparison=Image.new('RGB',(2560,756),'#35291f');draw=ImageDraw.Draw(comparison)
 for i,path in enumerate([before,after]):
  comparison.paste(Image.open(path).convert('RGB'),(1280*i,36));draw.text((16+i*1280,4),'之前的紧凑/分栏布局' if i==0 else '恢复原完整布局 · 实际 Godot 窗口',font=font,fill='#f4e7cd')
 comparison.save(OUT/f'compare-{kind}.png')
(OUT/'screenshots.json').write_text(json.dumps({'baseline_commit':'536e30e','platform':'Linux Godot4.3 Xvfb/Mesa','android_device_tested':False,'captures':frames},ensure_ascii=False,indent=2)+'\n')
print(len(frames),'actual window captures and 5 comparisons')
