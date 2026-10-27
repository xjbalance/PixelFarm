"""Collect actual model/UI window frames and assemble labelled comparisons."""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/world-style07'
OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),20)
for phase in ['before','render']:
    record=json.loads((ROOT/f'builds/world-style07-{phase}.json').read_text())
    if record['failures']: raise SystemExit('World style evidence contains failures')
    prefix='before' if phase=='before' else 'after'
    for frame in record['captures']:
        src=ROOT/frame['path'].removeprefix('res://')
        dst=OUT/f'{prefix}-{frame["name"]}.png'
        shutil.copyfile(src,dst);frame['file']=str(dst.relative_to(ROOT))
    (OUT/f'{prefix}-screenshots.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
for name in ['farm_home','farm_market','village_people','home_people']:
    sheet=Image.new('RGB',(2560,756),'#35291f');draw=ImageDraw.Draw(sheet)
    for column,phase in enumerate(['before','after']):
        sheet.paste(Image.open(OUT/f'{phase}-{name}.png').convert('RGB'),(column*1280,36))
        draw.text((column*1280+16,4),'96a9667 · 原有材质' if column==0 else '统一材质 · 同坐标 / 12:00 · 实际 Godot 窗口',font=font,fill='#f4e7cd')
    sheet.save(OUT/f'compare-{name}.png')
print('Collected actual world frames, four comparisons and two manifests')
