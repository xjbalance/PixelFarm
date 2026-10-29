"""Render festival icon regressions and farm evidence in an isolated Godot window."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT/'builds/festival-icons-after')
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
display = next(f':{n}' for n in range(150, 190)
               if not Path(f'/tmp/.X11-unix/X{n}').exists()
               and not Path(f'/tmp/.X{n}-lock').exists())
with tempfile.TemporaryDirectory(prefix='festival-icon-window-') as profile:
    server = subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'), display,
                               '-screen', '0', '1280x720x24', '-nolisten', 'tcp'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(.4)
        env = dict(os.environ, DISPLAY=display, LIBGL_ALWAYS_SOFTWARE='1',
                   XDG_DATA_HOME=profile, APPDATA=profile)
        result = subprocess.run([str(ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'),
                                 '--path', str(ROOT), '--audio-driver', 'Dummy',
                                 'res://tests/festival_visual_runner.tscn', '--',
                                 '--capture-dir='+str(output)], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=90)
        (output/'window.log').write_text(result.stdout)
        print(result.stdout)
        report = json.loads((output/'result.json').read_text())
        if result.returncode or report['failures'] or 'SCRIPT ERROR:' in result.stdout:
            raise SystemExit(1)
    finally:
        server.terminate()
        server.wait(timeout=10)
