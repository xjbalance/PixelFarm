"""Summarize only complete successful executions of the final UI/art source."""
from pathlib import Path
import ast,hashlib,json,re,subprocess

ROOT=Path(__file__).resolve().parents[1]
head=(ROOT/'builds/ui07-final-check.log').read_text()
window=(ROOT/'builds/ui07-final-window.log').read_text()
bad=re.compile(r'\bFAIL(?:ED)?\b|SCRIPT ERROR:|^ERROR:|instances leaked',re.M)
if 'ALL CHECKS PASSED' not in head or 'WINDOW MATRIX PASSED' not in window: raise SystemExit('Complete regression has not passed')
if bad.search(head) or bad.search(window): raise SystemExit('Final regression logs contain errors')
steps=next(ast.literal_eval(n.value) for n in ast.parse((ROOT/'tools/check_project.py').read_text()).body
           if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets))
passed=re.findall(r'^\[([^\]]+)\] PASS$',head,re.M)
if passed!=[step[0] for step in steps]: raise SystemExit('Not all planned processes executed')
for name,marker in [('ui07-final-apk-runtime.log','APK CODE INVARIANTS: PASS'),('ui07-final-interrupt.log','ACTUAL PROCESS INTERRUPT AND RESTART: PASS')]:
    log=(ROOT/'builds'/name).read_text()
    if marker not in log or bad.search(log): raise SystemExit(name+' did not pass')
def suites(text):
    return [{'suite':m[1],'checks':int(m[2]),'failures':int(m[3])} for m in re.finditer(r'^([^\n]*?RESULT): (\d+) checks, (\d+) failures',text,re.M)]
hs,ws=suites(head),suites(window)
paths=set(subprocess.check_output(['git','diff','--name-only','96a9667','--','scripts','assets','resources','project.godot','export_presets.cfg'],cwd=ROOT,text=True).splitlines())
paths.add('scripts/ui/facility_layout.gd');paths.add('resources/ui/world_style07.json')
apk=ROOT/'builds/PixelWorld-0.7.1-debug.apk'
record={'version':'0.7.1','save_version':24,'baseline_commit':'96a9667',
        'headless':{'checks':sum(x['checks'] for x in hs),'failures':0,'process_steps':len(passed),'suites':hs},
        'window':{'checks':sum(x['checks'] for x in ws),'failures':0,'suite_count':len(ws),'suites':ws,'platform':'Linux Godot 4.3 Xvfb/Mesa'},
        'new_suites':[x for x in hs+ws if any(tag in x['suite'] for tag in ['JOURNAL ATLAS','STORY UI07','FACILITY UI07','WORLD STYLE07'])],
        'apk':{'file':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'version_code':18,'package':'org.pixelfarm.windbud'},
        'android_device_tested':False,'interrupt_restart_passed':True,'apk_desktop_resources_passed':True,
        'tested_production_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(paths) if (ROOT/p).is_file()},
        'logs':['builds/ui07-final-check.log','builds/ui07-final-window.log','builds/ui07-final-build.log','builds/ui07-final-apk-runtime.log','builds/ui07-final-interrupt.log']}
(ROOT/'docs/TEST-UI07.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(record['headless']['checks'],record['window']['checks'],len(passed))
