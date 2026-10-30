"""Run real X11 Godot ranch acceptance; isolated saves, no user's world is loaded."""
from pathlib import Path
import os,subprocess,tempfile,time,sys
ROOT=Path(__file__).resolve().parents[1]
scene=sys.argv[1] if len(sys.argv)>1 else 'ranch082_baseline'
extra=sys.argv[2:]
project=ROOT
for option in list(extra):
 if option.startswith('--project='):project=Path(option.split('=',1)[1]);extra.remove(option)
display=next(f':{i}' for i in range(250,290) if not Path(f'/tmp/.X11-unix/X{i}').exists())
(ROOT/'docs/ranch082').mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='ranch082-window-') as profile:
 server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,'-screen','0','1920x1200x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 try:
  time.sleep(.4)
  env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
  cmd=[str(ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'),'--path',str(project),'--audio-driver','Dummy','--fixed-fps','60','--max-fps','0','res://tests/'+scene+'.tscn',*(['--',*extra] if extra else [])]
  run=subprocess.run(cmd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=480)
  (ROOT/'builds'/f'ranch082-{scene.replace(chr(47),chr(45))}.log').write_text(run.stdout)
  print(run.stdout[-6000:])
  if run.returncode or any(k in run.stdout for k in ['ERROR:','FAIL:','instances leaked']):raise SystemExit(1)
 finally:server.terminate();server.wait(timeout=10)
