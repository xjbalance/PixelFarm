"""Real Godot 4.3 window, isolated saves and software GL; never touches player saves."""
from pathlib import Path
import os, subprocess, tempfile, time, argparse
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--baseline',action='store_true');p.add_argument('--sample',action='store_true');args=p.parse_args()
(ROOT/'docs/harvest-workshop').mkdir(parents=True,exist_ok=True)
display=next(f':{i}' for i in range(190,220) if not Path(f'/tmp/.X11-unix/X{i}').exists())
with tempfile.TemporaryDirectory(prefix='harvest-window-') as profile:
    server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,'-screen','0','1800x1100x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        time.sleep(.5)
        env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
        scene='harvest_baseline' if args.baseline else 'harvest_sample' if args.sample else 'harvest_render'
        run=subprocess.run([str(ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'),'--path',str(ROOT),'--audio-driver','Dummy','--fixed-fps','60','res://tests/'+scene+'.tscn'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
        (ROOT/'builds'/f'{scene}-window.log').write_text(run.stdout)
        print(run.stdout[-6000:])
        if run.returncode or any(x in run.stdout for x in ['ERROR:','SCRIPT ERROR:','instances leaked']): raise SystemExit(1)
    finally:
        server.terminate();server.wait(timeout=10)
