"""整理住宅实际窗口帧、前后对照和三帧小睡演示；不生成或伪造游戏界面。"""
from pathlib import Path
import json, shutil
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/home05'
OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
record=json.loads((ROOT/'builds/home05-render-evidence.json').read_text())
if record['failures']:raise SystemExit('窗口尚有失败，拒绝整理通过画面')
for item in record['captures']:
 source=ROOT/item['path'].removeprefix('res://');target=OUT/(item['name']+'.png');shutil.copyfile(source,target);item['file']=str(target.relative_to(ROOT))
for label in ['home-level1','home-level2','home-level3','home-kitchen','home-bed']:
 source=ROOT/f'builds/ui05-home05-before-1280x720-{label}.png'
 shutil.copyfile(source,OUT/('before-'+label+'.png'))
font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),20)
def paired(left,right,name):
 images=[Image.open(OUT/left).convert('RGB'),Image.open(OUT/right).convert('RGB')]
 result=Image.new('RGB',(2560,756),'#35291f');draw=ImageDraw.Draw(result)
 for i,im in enumerate(images):
  result.paste(im,(i*1280,36));draw.text((16+i*1280,4),'改版前 · 6c904f0' if i==0 else '住宅05 · 实际 Godot 窗口',font=font,fill='#f4e7cd')
 result.save(OUT/name)
paired('before-home-level1.png','level_1.png','compare-interior.png')
paired('before-home-kitchen.png','kitchen.png','compare-kitchen.png')
paired('before-home-bed.png','bed_confirmation.png','compare-bed-ui.png')
names=['温馨小屋','舒适农舍','河湾大屋','星光庄园'];sheet=Image.new('RGB',(1280,792),'#35291f');draw=ImageDraw.Draw(sheet)
for i,name in enumerate(names):
 x=(i%2)*640;y=(i//2)*396
 draw.text((x+14,y+3),f'{i+1}级 · {name}',font=font,fill='#f4e7cd')
 sheet.paste(Image.open(OUT/f'level_{i+1}.png').resize((640,360),Image.NEAREST),(x,y+36))
sheet.save(OUT/'four-levels.png')
frames=[Image.open(OUT/f'{name}.png').convert('RGB').resize((960,540),Image.NEAREST).quantize(colors=256,dither=Image.NONE) for name in ['sofa_before','sofa_transition','sofa_after']]
frames[0].save(OUT/'sofa-demo.gif',save_all=True,append_images=frames[1:],duration=[1500,250,1500],loop=0,disposal=2)
record.update({'baseline_commit':'6c904f0','platform':'Linux Godot 4.3 Xvfb/Mesa','android_device_tested':False,'gif_note':'Three actual rendered state frames; not an Android recording or FPS sample.'})
(OUT/'screenshots.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(f'{len(record["captures"])} actual captures / four-level sheet / 3 comparisons / 3-frame nap GIF')
