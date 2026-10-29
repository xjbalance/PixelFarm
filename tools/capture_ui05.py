"""在隔离用户目录的真实 Godot 窗口捕获UI05（Linux Xvfb/Mesa，不是Android）。"""
from pathlib import Path
import argparse, os, subprocess, tempfile, time
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--phase',default='after')
p.add_argument('--extra',action='store_true',help='小京剧情、设置、村民、家具、钓鱼图鉴')
a=p.parse_args()
if not a.phase or len(a.phase)>32 or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_' for c in a.phase): p.error('phase必须是安全文件名标签')
server=None
try:
 display=next((f':{n}' for n in range(99,120) if not Path(f'/tmp/.X11-unix/X{n}').exists() and not Path(f'/tmp/.X{n}-lock').exists()),None)
 if not display: raise RuntimeError('没有空闲X11显示号')
 server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,'-screen','0','1800x1100x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 time.sleep(.4)
 if server.poll() is not None: raise RuntimeError('Xvfb启动失败')
 with tempfile.TemporaryDirectory(prefix='pixel-ui05-capture-') as profile:
  env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
  with (ROOT/f'builds/ui05-{a.phase}-capture.log').open('w') as log:
   result=subprocess.run([str(ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'),'--path',str(ROOT),'--audio-driver','Dummy','--fixed-fps','60','--max-fps','0','res://tests/ui05_capture.tscn','--','--phase='+a.phase,*(['--extra'] if a.extra else [])],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240)
  text=(ROOT/f'builds/ui05-{a.phase}-capture.log').read_text()
  print(*[x for x in text.splitlines() if 'CAPTURE' in x],sep='\n')
  if result.returncode or any(x in text for x in ['ERROR:','FAIL:','instances leaked']): raise SystemExit('捕获失败，查看builds日志')
finally:
 if server: server.terminate();server.wait(timeout=10)
