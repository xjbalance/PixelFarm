"""Collect executed suite/build evidence and compose labeled comparisons from real captures."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import ast,hashlib,json,re,subprocess,datetime
R=Path(__file__).resolve().parents[1];D=R/'docs/ranch082';B=R/'builds'
def read(name):return json.loads((D/name).read_text())
module=ast.parse((R/'tools/check_project.py').read_text());steps=ast.literal_eval(next(n.value for n in module.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets)))
records=[]
for name,_ in steps:
 p=B/(name+'.log');s=p.read_text() if p.exists() else ''
 checks=sum(int(a) for a,b in re.findall(r'RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures',s))
 records.append({'process':name,'log':'builds/'+p.name,'checks':checks,'engine_error':any(x in s for x in ['SCRIPT ERROR:','ERROR:','FAIL:','instances leaked']),'exists':p.exists()})
full=(B/'ranch082-final-regression.log').read_text() if (B/'ranch082-final-regression.log').exists() else ''
complete='ALL CHECKS PASSED:' in full
windows={}
for scene,filename in [('ranch_ranges','ranch082-ranch082_ranges_runner.log'),('farm','ranch082-ranch082_farm_runner.log'),('natural_obstacles','ranch082-ranch082_obstacle_runner.log'),('stress','ranch082-ranch082_stress_runner.log'),('seasons','ranch082-ranch082_season_probe.log')]:
 p=B/filename;s=p.read_text() if p.exists() else''
 windows[scene]={'checks':sum(int(a) for a,b in re.findall(r'RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures',s)),'errors':any(x in s for x in ['ERROR:','FAIL:','instances leaked']),'log':'builds/'+filename}
for label,name in [('ranch_ui','ui-matrix-window-results.json'),('ranch_ui_dpi480','ui-dpi480-window-results.json')]:
 if (D/name).exists():
  j=read(name);windows[label]={'checks':j['checks'],'errors':j['failures']!=0,'actual_window':j['actual_window'],'result':'docs/ranch082/'+name}
for scene in ['livestock_b_render','kitchen_b_render','ui05_camera_runner','territory_editor_render','home05_render']:
 p=B/f'window-082-{scene}.log';s=p.read_text() if p.exists() else''
 windows[scene]={'checks':sum(int(a) for a,b in re.findall(r'RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures',s)),'errors':any(x in s for x in ['ERROR:','FAIL:','instances leaked']),'log':'builds/'+p.name}
builds={}
for name in ['PixelWorld-0.8.2-Windows-x64.zip','PixelWorld-0.8.2-debug.apk']:
 p=B/name
 if p.exists(): builds[name]={'size_bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
result={'version':'0.8.2','title':'活力牧场','base_commit':'244c379','branch':'development/0.8.2','save_version':30,'baseline':read('baseline-tests.json'),'regression':{'complete_fresh_run':complete,'processes':len(steps),'assertions':sum(x['checks'] for x in records),'errors':sum(x['engine_error'] for x in records),'records':records},'windows':{'assertions':sum(x['checks'] for x in windows.values()),'suites':windows},'farm':read('farm-results.json')['area'],'pastures':read('ranges-results.json')['areas'],'builds':builds,'platform_limits':{'android_physical_device_tested':False,'windows_native_hardware_tested':False,'windows_wine_tested':'ACTUAL WINDOWS EXE UNDER WINE: PASS' in (B/'ranch082-windows-runtime.log').read_text() if (B/'ranch082-windows-runtime.log').exists() else False},'generated_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(D/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
font=ImageFont.truetype(str(R/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),30)
def compare(a,b,name,labels):
 left=Image.open(D/a).convert('RGB');right=Image.open(D/b).convert('RGB')
 width=left.width+right.width+24;h=max(left.height,right.height)+76
 canvas=Image.new('RGB',(width,h),'#eddfbd');draw=ImageDraw.Draw(canvas)
 canvas.paste(left,(0,76));canvas.paste(right,(left.width+24,76));draw.text((20,16),labels[0],font=font,fill='#634c3b');draw.text((left.width+44,16),labels[1],font=font,fill='#634c3b');canvas.save(D/name)
compare('before-farm-native.png','after-farm-initial.png','comparison-farm-native.png',['0.8.1 · 48×32 · 原生比例','0.8.2 · 96×64 · 同一原生像素比例，旧坐标保留'])
compare('clearing-before.png','clearing-after.png','comparison-clearing.png',['清理前 · 实际 Godot 窗口','清理后 · 碰撞释放，永久开垦'])
after=Image.open(D/'after-farm-initial.png').convert('RGBA');overlay=Image.new('RGBA',after.size);draw=ImageDraw.Draw(overlay)
draw.rectangle((1,1,1535,1023),outline='#f7e8a5',width=6);draw.text((28,20),'原48×32区域 · 世界坐标不变',font=font,fill='#fff4df',stroke_width=2,stroke_fill='#634c3b')
config=json.loads((R/'resources/farm_layout/expansion082.json').read_text())
for data in config['zones'].values():
 x,y,w,h=data['rect'];rect=(x*32,y*32,(x+w)*32,(y+h)*32)
 draw.rectangle(rect,outline=(239,218,169,180),width=3);draw.text((x*32+10,y*32+8),data['name']+' · 参考分区，可自行改造',font=font,fill='#fff4df',stroke_width=2,stroke_fill='#634c3b')
Image.alpha_composite(after,overlay).save(D/'farm-boundaries-annotated.png')
for site in ['coop','barn','fold']:
 for action,duration in [('walk',500),('return',1000),('graze',250)]:
  paths=sorted(D.glob(f'{site}-{action}-[0-9]*.png'))
  if not paths:continue
  frames=[Image.open(p).convert('RGB') for p in paths]
  output={'walk':'walking','return':'returning','graze':'grazing'}[action]
  frames[0].save(D/f'{site}-{output}.gif',save_all=True,append_images=frames[1:],duration=duration,loop=0,optimize=True)
# Window-scale overview of native seasonal captures; source images stay unmodified.
canvas=Image.new('RGB',(1536,1088),'#eddfbd');draw=ImageDraw.Draw(canvas)
for i,season in enumerate(['spring','summer','autumn','winter']):
 im=Image.open(D/f'farm-season-{season}.png').convert('RGB');im=im.resize((768,512),Image.NEAREST)
 x=(i%2)*768;y=(i//2)*544;canvas.paste(im,(x,y+32));draw.text((x+16,y),['春','夏','秋','冬'][i]+' · 实际游戏全景缩览',font=font,fill='#634c3b')
canvas.save(D/'farm-four-seasons.png')
# Preserve delivered executable evidence in the report folder.
for source,target in [('windows080-wine-report.json','windows-runtime.json'),('ranch082-apk-runtime.log','apk-runtime.txt')]:
 p=B/source
 if p.exists():
  if target.endswith('.txt'):(D/target).write_text(p.read_text().rstrip()+'\n')
  else:(D/target).write_bytes(p.read_bytes())
changed=set(subprocess.check_output(['git','diff','--name-only','244c379'],cwd=R,text=True).splitlines())
for line in subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=R,text=True).splitlines():
 if line.startswith('need/') or line.endswith('.import') and line.startswith('docs/'):continue
 changed.add(line)
(D/'changed-files.txt').write_text('\n'.join(sorted(changed))+'\n')
print('REGRESSION:',len(steps),'processes;',result['regression']['assertions'],'assertions; fresh_complete',complete,'errors',result['regression']['errors'])
print('ACTUAL WINDOW:',result['windows']['assertions'],'checks;',len(windows),'suites')
