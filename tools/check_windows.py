"""Linux真实窗口回归（Xvfb/Mesa或指定DISPLAY）；不代表Android真机验收。"""
from pathlib import Path
import argparse,os,subprocess,tempfile,time,re
ROOT=Path(__file__).resolve().parents[1]
VERSION=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(),re.M).group(1)
TAG=VERSION.replace('.','')
SUITES=['render_061','render_062','render_seasons_a','fishing_b_render','livestock_b_render','kitchen_b_render','life_c_render','exploration_d_render','world_progress_d_render','finale_070_render','palm_ui_render','palm_runner','tutorial_071_runner','touch_polish_runner','touch_polish_visual','farming_visual_runner','food_recovery_runner']
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--display');p.add_argument('--suite',action='append',choices=SUITES);args=p.parse_args()
engine=ROOT/'.tools/Godot_v4.3-stable_linux.x86_64';server=None
history={path:path.read_bytes() for pattern in ['screenshot*.png'] for path in (ROOT/'docs').glob(pattern)}
try:
 # 可单独从新源码调用，先等Godot完成全量导入和全局脚本类型注册。
 with tempfile.TemporaryDirectory(prefix='pixel-world-window-import-') as profile:
  env=dict(os.environ,XDG_DATA_HOME=profile,APPDATA=profile)
  imported=subprocess.run([str(engine),'--headless','--path',str(ROOT),'--import'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
  (ROOT/'builds'/f'window-{TAG}-import.log').write_text(imported.stdout)
  if imported.returncode or any(marker in imported.stdout for marker in ['ERROR:','SCRIPT ERROR:']): raise RuntimeError('窗口测试前导入失败，请检查import日志。')
 display=args.display
 if not display:
  for number in range(99,120):
   if not Path(f'/tmp/.X11-unix/X{number}').exists() and not Path(f'/tmp/.X{number}-lock').exists(): display=f':{number}';break
  if not display: raise RuntimeError('没有空闲显示号，请用--display指定。')
  binary=ROOT/'.tools/display/usr/bin/Xvfb'
  if not binary.exists(): raise RuntimeError('缺少便携Xvfb，请用--display指定已有显示。')
  server=subprocess.Popen([str(binary),display,'-screen','0','1600x1000x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(.4)
  if server.poll() is not None: raise RuntimeError('Xvfb启动失败。')
 for suite in args.suite or SUITES:
  with tempfile.TemporaryDirectory(prefix='pixel-world-window-') as profile:
   env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
   with (ROOT/'builds'/f'window-{TAG}-{suite}.log').open('w') as log:
    result=subprocess.run([str(engine),'--path',str(ROOT),'--audio-driver','Dummy','--fixed-fps','60','--max-fps','0',f'res://tests/{suite}.tscn'],env=env,stdout=log,stderr=subprocess.STDOUT,text=True,timeout=240)
   text=(ROOT/'builds'/f'window-{TAG}-{suite}.log').read_text();print(suite,':[',result.returncode,']',*[line for line in text.splitlines() if 'RESULT:' in line],flush=True)
   if result.returncode or any(marker in text for marker in ['ERROR:','FAIL:','instances leaked']): raise SystemExit(1)
   if VERSION=='0.7.0' and suite=='render_062':
    for old,new in [('screenshot-062-lake.png','screenshot-070-farm.png'),('screenshot-062-panel.png','screenshot-070-fishpens.png')]: (ROOT/'docs'/new).write_bytes((ROOT/'docs'/old).read_bytes())
 for old,new in [('screenshot-exploration-forest.png','screenshot-070-forest.png'),('screenshot-exploration-lake.png','screenshot-070-ruins.png'),('screenshot-exploration-temple.png','screenshot-070-temple.png'),('world-progress-d-dock.png','screenshot-070-dock.png'),('world-progress-d-community.png','screenshot-070-community.png')]:
  source=ROOT/'builds'/old
  if VERSION=='0.7.0' and source.exists(): (ROOT/'docs'/new).write_bytes(source.read_bytes())
 print('WINDOW MATRIX PASSED (DESKTOP ONLY)')
finally:
 for path,data in history.items(): path.write_bytes(data)
 if server: server.terminate();server.wait(timeout=10)
