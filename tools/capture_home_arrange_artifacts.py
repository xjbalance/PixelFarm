"""整理住宅实际窗口截图与家具布置演示；Pillow仅拼图，不生成游戏画面。"""
from pathlib import Path
import json,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/home-arrange'
OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
record=json.loads((ROOT/'builds/home-arrange-render-evidence.json').read_text())
if record['failures']:raise SystemExit('窗口仍有失败')
for item in record['captures']:
 src=ROOT/item['path'].removeprefix('res://');target=OUT/(item['name']+'.png');shutil.copyfile(src,target);item['file']=str(target.relative_to(ROOT))
font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),20)
for level in range(1,5):shutil.copyfile(ROOT/f'builds/home05-level_{level}.png',OUT/f'warm-level-{level}.png')
old=ROOT/'builds/home-arrange-before/home05-level_1.png';shutil.copyfile(old,OUT/'old-interior.png')
comparison=Image.new('RGB',(2560,756),'#35291f');draw=ImageDraw.Draw(comparison)
for i,file in enumerate([OUT/'old-interior.png',OUT/'warm-level-1.png']):
 comparison.paste(Image.open(file).convert('RGB'),(i*1280,36));draw.text((i*1280+16,4),'a09a661 · 改造前' if i==0 else '温馨田园 · 实际 Godot 窗口',font=font,fill='#f4e7cd')
comparison.save(OUT/'compare-interior.png')
sheet=Image.new('RGB',(1280,792),'#35291f');d=ImageDraw.Draw(sheet)
for i,title in enumerate(['温馨小屋','舒适农舍','河湾大屋','星光庄园']):
 x=i%2*640;y=i//2*396;d.text((x+14,y+4),f'{i+1}级 · {title}',font=font,fill='#f4e7cd');sheet.paste(Image.open(OUT/f'warm-level-{i+1}.png').resize((640,360),Image.NEAREST),(x,y+36))
sheet.save(OUT/'four-levels.png')
frames=[Image.open(OUT/f'{label}.png').convert('RGB').resize((960,540),Image.NEAREST).quantize(colors=256,dither=Image.NONE) for label in ['before','bed_preview','bed_after','sofa_preview','sofa_after','kitchen_preview','kitchen_after']]
frames[0].save(OUT/'arrange-demo.gif',save_all=True,append_images=frames[1:],duration=[1400]*len(frames),loop=0,disposal=2)
record.update({'baseline_commit':'a09a661','save_version':24,'gif_note':'Sequence of actual rendered state frames, not an Android recording or FPS measurement.'})
(OUT/'screenshots.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(len(record['captures']),'actual arrangement captures, four levels and comparison/GIF')
