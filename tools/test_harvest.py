"""Run a selected real-scene regression with isolated saves and fail on engine errors."""
import os,subprocess,tempfile,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
scenes=sys.argv[1:] or ['harvest_crops_runner']
with tempfile.TemporaryDirectory(prefix='harvest-test-') as profile:
    env=dict(os.environ,XDG_DATA_HOME=profile,APPDATA=profile)
    for scene in scenes:
        base,*extra=scene.split(':')
        opts=['--editor','--import'] if base=='import' else ['--fixed-fps','60','res://tests/'+base+'.tscn']+(['--','--'+extra[0]] if extra else [])
        run=subprocess.run([str(ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'),'--headless','--path',str(ROOT),*opts],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
        (ROOT/'builds'/('harvest-'+scene+'.log')).write_text(run.stdout)
        lines=[x for x in run.stdout.splitlines() if any(k in x for k in ['ERROR:','RESULT','FAIL:',' at:'])]
        print(scene+':\n'+'\n'.join(lines[-45:]),flush=True)
        if run.returncode or any(k in run.stdout for k in ['ERROR:','SCRIPT ERROR:','instances leaked']):raise SystemExit(1)
