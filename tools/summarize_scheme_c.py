"""从完整通过的实际日志整理方案C验收，不把素材预览当作真机测试。"""
from pathlib import Path
import ast,hashlib,json,re,subprocess

ROOT=Path(__file__).resolve().parents[1]
head=(ROOT/'builds/scheme-c-final-check.log').read_text()
window=(ROOT/'builds/scheme-c-final-window.log').read_text()
bad=re.compile(r'\bFAIL(?:ED)?\b|SCRIPT ERROR:|^ERROR:|instances leaked',re.M)
if 'ALL CHECKS PASSED' not in head or 'WINDOW MATRIX PASSED' not in window: raise SystemExit('Full final test run is incomplete')
if bad.search(head) or bad.search(window): raise SystemExit('Final run contains errors')
steps=next(ast.literal_eval(n.value) for n in ast.parse((ROOT/'tools/check_project.py').read_text()).body
           if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets))
passed=re.findall(r'^\[([^\]]+)\] PASS$',head,re.M)
if passed!=[step[0] for step in steps]: raise SystemExit('Not all planned processes executed')
for name,marker in [('scheme-c-final-apk-runtime.log','APK CODE INVARIANTS: PASS'),('scheme-c-final-interrupt.log','ACTUAL PROCESS INTERRUPT AND RESTART: PASS')]:
    log=(ROOT/'builds'/name).read_text()
    if marker not in log or bad.search(log): raise SystemExit(name+' did not pass')
def suites(text):
    return [{'suite':m[1],'checks':int(m[2]),'failures':int(m[3])} for m in re.finditer(r'^([^\n]*?RESULT): (\d+) checks, (\d+) failures',text,re.M)]
hs,ws=suites(head),suites(window)
paths=set(subprocess.check_output(['git','diff','--name-only','94f18cd','--','scripts','assets','resources','scenes','project.godot','export_presets.cfg'],cwd=ROOT,text=True).splitlines())
for directory in ['scripts/appearance','assets/characters/scheme_c']:
    paths.update(str(p.relative_to(ROOT)) for p in (ROOT/directory).rglob('*') if p.is_file())
apk=ROOT/'builds/PixelWorld-0.7.1-debug.apk'
record={'version':'0.7.1','save_version':25,'baseline_commit':'94f18cd','design_scheme':'C',
        'linkage':{'player_male':'xiaojing_female','player_female':'xiaojing_male'},
        'headless':{'checks':sum(x['checks'] for x in hs),'failures':0,'process_steps':len(passed),'suites':hs},
        'window':{'checks':sum(x['checks'] for x in ws),'failures':0,'suite_count':len(ws),'suites':ws,'platform':'Linux Godot 4.3 Xvfb/Mesa'},
        'new_suites':[x for x in hs+ws if any(tag in x['suite'] for tag in ['APPEARANCE','CHARACTER SELECT','SCHEME C'])],
        'female_deep_regression':json.loads((ROOT/'builds/scheme-c-female-regression-summary.json').read_text()),
        'apk':{'file':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'version_code':19,'package':'org.pixelfarm.windbud'},
        'android_device_tested':False,'physical_gamepad_tested':False,'interrupt_restart_passed':True,'apk_desktop_resources_passed':True,
        'tested_production_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(paths) if (ROOT/p).is_file()},
        'logs':['builds/scheme-c-final-check.log','builds/scheme-c-final-window.log','builds/scheme-c-final-build.log','builds/scheme-c-final-apk-runtime.log','builds/scheme-c-final-interrupt.log']}
(ROOT/'docs/TEST-SCHEME-C.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(record['headless']['checks'],record['window']['checks'],len(passed))
