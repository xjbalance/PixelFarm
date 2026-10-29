"""由完整成功执行的日志生成住宅自由布置验收记录。"""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
head=(ROOT/'builds/home-arrange-final-check.log').read_text();window=(ROOT/'builds/home-arrange-final-window.log').read_text()
if 'ALL CHECKS PASSED' not in head or 'WINDOW MATRIX PASSED' not in window:raise SystemExit('完整测试尚未全部成功')
def has_errors(log):return re.search(r'\bFAIL(?:ED)?\b|SCRIPT ERROR:|^ERROR:|instances leaked',log,re.M)
if any(has_errors(s) for s in [head,window]):raise SystemExit('日志中存在错误')
steps=next(ast.literal_eval(n.value) for n in ast.parse((ROOT/'tools/check_project.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets))
passed=re.findall(r'^\[([^\]]+)\] PASS$',head,re.M)
if passed!=[step[0] for step in steps]:raise SystemExit('计划进程没有完整执行')
for file,marker in [('home-arrange-final-apk-runtime.log','APK CODE INVARIANTS: PASS'),('home-arrange-final-interrupt.log','ACTUAL PROCESS INTERRUPT AND RESTART: PASS')]:
 log=(ROOT/'builds'/file).read_text()
 if marker not in log or has_errors(log):raise SystemExit(file+'未通过')
def suites(text):return [{'suite':m.group(1),'checks':int(m.group(2)),'failures':int(m.group(3))} for m in re.finditer(r'^([^\n]*?RESULT): (\d+) checks, (\d+) failures',text,re.M)]
hs=suites(head);ws=suites(window)
paths=set(subprocess.check_output(['git','diff','--name-only','a09a661','--','scripts','resources','project.godot','export_presets.cfg'],cwd=ROOT,text=True).splitlines())
paths.update(str(p.relative_to(ROOT)) for p in (ROOT/'scripts/housing').glob('home_*.gd'))
paths.update(str(p.relative_to(ROOT)) for p in (ROOT/'assets/housing/interior').glob('*.png'))
apk=ROOT/'builds/PixelWorld-0.7.1-debug.apk'
record={'version':'0.7.1','save_version':24,'baseline_commit':'a09a661','baseline_related_checks':500,'baseline_window_checks':44,'headless':{'checks':sum(x['checks'] for x in hs),'failures':0,'process_steps':len(passed),'suites':hs},'window':{'checks':sum(x['checks'] for x in ws),'failures':0,'suite_count':len(ws),'suites':ws,'platform':'Linux Godot 4.3 Xvfb/Mesa'},'new_suites':[x for x in hs+ws if 'HOME ARRANGE' in x['suite']],'apk':{'file':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'version_code':16,'package':'org.pixelfarm.windbud'},'android_device_tested':False,'interrupt_restart_passed':True,'apk_desktop_resources_passed':True,'tested_production_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(paths) if (ROOT/p).is_file()},'logs':['builds/home-arrange-final-check.log','builds/home-arrange-final-window.log','builds/home-arrange-final-build.log','builds/home-arrange-final-apk-runtime.log','builds/home-arrange-final-interrupt.log']}
(ROOT/'docs/TEST-HOME-ARRANGE.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(record['headless']['checks'],record['window']['checks'],len(passed))
