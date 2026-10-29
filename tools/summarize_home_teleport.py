"""从实际专项与相关回归日志整理回家按钮验收，不冒称重新执行全部历史套件。"""
from pathlib import Path
import hashlib,json,re,shutil,subprocess

ROOT=Path(__file__).resolve().parents[1]
def passed(name):
    text=(ROOT/'builds'/name).read_text()
    if re.search(r'ERROR:|FAIL:|instances leaked|[1-9]\d* failures',text):raise SystemExit(name+' contains errors')
    return text
state=passed('home-teleport-state.log')
window=passed('window-071-home_teleport_render.log')
old_window=passed('home-teleport-existing-window.log')
logs={name:passed('home-return-regression-'+name+'.log') for name in ['touch_polish_runner','ui05_camera_runner','farming_actions_runner','scheme_c_game_runner']}
for name,marker in [('home-teleport-apk-runtime.log','APK CODE INVARIANTS: PASS')]:
    if marker not in passed(name):raise SystemExit(name+' incomplete')
def checks(text):return sum(int(x) for x in re.findall(r'RESULT: (\d+) checks, 0 failures',text))
assert checks(state)>0 and checks(window)>0 and 'WINDOW MATRIX PASSED' in old_window
out=ROOT/'docs/home-teleport';out.mkdir(exist_ok=True);(out/'.gdignore').touch()
frames=json.loads((ROOT/'builds/home-teleport-render.json').read_text())
assert frames['failures']==0
for frame in frames['captures']:
    src=ROOT/frame['path'].removeprefix('res://');dst=out/(frame['name']+'.png');shutil.copyfile(src,dst);frame['file']=str(dst.relative_to(ROOT))
(out/'screenshots.json').write_text(json.dumps(frames,ensure_ascii=False,indent=2)+'\n')
paths=set(subprocess.check_output(['git','diff','--name-only','69ca84e','--','scripts','assets','export_presets.cfg'],cwd=ROOT,text=True).splitlines())
paths.update(['scripts/world/home_return_controller.gd','assets/ui/home_return.svg','assets/ui/home_return.svg.import'])
apk=ROOT/'builds/PixelWorld-0.7.1-debug.apk'
record={'baseline':'69ca84e','save_version':25,'new_state_checks':checks(state),'new_window_checks':checks(window),
        'related_existing_state_checks':sum(checks(text) for text in logs.values()),'related_existing_window_checks':checks(old_window),
        'failures':0,'android_device_tested':False,'desktop_platform':'Linux Godot4.3 Xvfb/Mesa',
        'apk':{'version_code':20,'package':'org.pixelfarm.windbud','bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest()},
        'tested_production_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(paths)},
        'note':'Targeted feature tests and relevant existing regressions; not a rerun of all 6087 historical assertions.'}
(ROOT/'docs/TEST-HOME-TELEPORT.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(record)
