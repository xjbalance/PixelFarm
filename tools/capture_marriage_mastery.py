"""Run real-window marriage achievement and existing ceremony regressions."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/marriage-mastery'
OUT.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--odds-only',action='store_true')
args=parser.parse_args()
display=next(f':{n}' for n in range(150,190)
             if not Path(f'/tmp/.X11-unix/X{n}').exists() and not Path(f'/tmp/.X{n}-lock').exists())
with tempfile.TemporaryDirectory(prefix='marriage-mastery-window-') as profile:
    server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,
                             '-screen','0','1800x1100x24','-nolisten','tcp'],
                            stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        time.sleep(.4)
        env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
        scenes=['fishing_odds_runner'] if args.odds_only else ['marriage_mastery_runner','marriage_requirements_render','fishing_odds_runner']
        for scene in scenes:
            run=subprocess.run([str(ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'),
                                '--path',str(ROOT),'--audio-driver','Dummy','--fixed-fps','60',
                                'res://tests/'+scene+'.tscn','--','--capture'],env=env,
                               stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
            (ROOT/'builds'/('marriage-mastery-window-'+scene+'.log')).write_text(run.stdout)
            print('\n'.join(line for line in run.stdout.splitlines() if 'RESULT' in line or 'ERROR:' in line),flush=True)
            if run.returncode or any(marker in run.stdout for marker in ['ERROR:','SCRIPT ERROR:','instances leaked']):
                raise SystemExit('Window regression failed: '+scene)
        for pattern in ['marriage-mastery-*.png','marriage-requirements-*.png','fishing-odds-*.png']:
            for path in (ROOT/'builds').glob(pattern): shutil.copyfile(path,OUT/path.name)
        for name in ['marriage-mastery-render.json','marriage-requirements-render.json','fishing-odds-render.json']:
            shutil.copyfile(ROOT/'builds'/name,OUT/name)
    finally:
        server.terminate();server.wait(timeout=10)
