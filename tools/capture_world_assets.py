"""Capture identical real-window fixtures before (Git HEAD) and after integration."""
import argparse
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--before', action='store_true')
args = parser.parse_args()
phase = 'before' if args.before else 'after'
output = ROOT/'docs/need-assets'/phase
output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='world-art-capture-') as tmp:
    profile = Path(tmp)/'profile'
    project = ROOT
    if args.before:
        project=Path(tmp)/'original'
        project.mkdir()
        data=subprocess.check_output(['git','archive','HEAD'],cwd=ROOT)
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            archive.extractall(project)
        for name in ['world_assets_capture.gd','world_assets_capture.tscn']:
            shutil.copy2(ROOT/'tests'/name,project/'tests'/name)
    display = next(f':{n}' for n in range(150,190) if not Path(f'/tmp/.X11-unix/X{n}').exists() and not Path(f'/tmp/.X{n}-lock').exists())
    server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,'-screen','0','1800x1100x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        time.sleep(.4)
        env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=str(profile),APPDATA=str(profile))
        if args.before:
            result=subprocess.run([str(ENGINE),'--headless','--path',str(project),'--import'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
            (ROOT/'builds/need-assets-before-import.log').write_text(result.stdout)
            if result.returncode or 'SCRIPT ERROR:' in result.stdout: raise RuntimeError('Baseline import failed')
        result=subprocess.run([str(ENGINE),'--path',str(project),'--audio-driver','Dummy','--fixed-fps','60','--max-fps','0','res://tests/world_assets_capture.tscn','--','--capture-dir='+str(output)],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
        (ROOT/f'builds/need-assets-{phase}-capture.log').write_text(result.stdout)
        print('\n'.join(x for x in result.stdout.splitlines() if 'CAPTURE' in x or 'ERROR' in x))
        if result.returncode or any(x in result.stdout for x in ['ERROR:','SCRIPT ERROR:','instances leaked']): raise RuntimeError('Capture failed, see builds log')
    finally:
        server.terminate();server.wait(timeout=10)
