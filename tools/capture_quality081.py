"""Real Godot window captures with isolated saves; baseline and revised art use identical fixtures."""
from pathlib import Path
import argparse,os,subprocess,tempfile,time
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--phase',choices=['before','sample','after'],default='after');p.add_argument('--scene',default='quality081_visual');args=p.parse_args()
(ROOT/'docs/quality081').mkdir(parents=True,exist_ok=True)
display=next(f':{i}' for i in range(220,250) if not Path(f'/tmp/.X11-unix/X{i}').exists())
with tempfile.TemporaryDirectory(prefix='quality081-window-') as profile:
 server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,'-screen','0','1800x1100x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 try:
  time.sleep(.4)
  env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
  cmd=[str(ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'),'--path',str(ROOT),'--audio-driver','Dummy','--fixed-fps','60','res://tests/'+args.scene+'.tscn','--','--'+args.phase]
  run=subprocess.run(cmd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
  (ROOT/'builds'/f'quality081-{args.scene}-{args.phase}.log').write_text(run.stdout)
  print(run.stdout[-5000:])
  if run.returncode or any(k in run.stdout for k in ['ERROR:','FAIL:','instances leaked']):raise SystemExit(1)
 finally:server.terminate();server.wait(timeout=10)
