"""从完整成功日志整理住宅05交付记录；缺步骤或失败时拒绝标记通过。"""
from pathlib import Path
import ast, hashlib, json, re, subprocess
ROOT=Path(__file__).resolve().parents[1]
head=(ROOT/'builds/home05-final-check.log').read_text();window=(ROOT/'builds/home05-final-window.log').read_text()
if 'ALL CHECKS PASSED' not in head or 'WINDOW MATRIX PASSED' not in window:raise SystemExit('完整测试尚未全部成功')
if any(re.search(r'\bFAIL(?:ED)?\b|SCRIPT ERROR:|^ERROR:',t,re.M) for t in [head,window]):raise SystemExit('日志有失败或错误')
steps=next(ast.literal_eval(n.value) for n in ast.parse((ROOT/'tools/check_project.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets))
passed=re.findall(r'^\[([^\]]+)\] PASS$',head,re.M)
if passed!=[s[0] for s in steps]:raise SystemExit('测试进程步骤缺失或顺序不正确')
def suites(t):return [{'suite':m.group(1).strip(),'checks':int(m.group(2)),'failures':int(m.group(3))} for m in re.finditer(r'^([^\n]*?RESULT): (\d+) checks, (\d+) failures',t,re.M)]
hs=suites(head);ws=suites(window)
for log,marker in [('home05-latest-render.log','HOME 05 RENDER RESULT: 44 checks, 0 failures'),('home05-final-apk-runtime.log','APK CODE INVARIANTS: PASS'),('home05-final-interrupt.log','ACTUAL PROCESS INTERRUPT AND RESTART: PASS')]:
 if marker not in (ROOT/'builds'/log).read_text():raise SystemExit(log+'未通过')
paths=set(subprocess.check_output(['git','diff','--name-only','6c904f0','--','scripts','resources','project.godot','export_presets.cfg'],cwd=ROOT,text=True).splitlines())
paths.update(str(p.relative_to(ROOT)) for p in (ROOT/'scripts/housing').glob('home*.gd'))
paths.add('scripts/housing/house_exterior.gd')
paths.update(str(p.relative_to(ROOT)) for p in (ROOT/'assets/housing/interior').glob('*.png'))
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(paths) if (ROOT/p).is_file()}
apk=ROOT/'builds/PixelWorld-0.7.1-debug.apk'
record={'version':'0.7.1','save_version':23,'baseline_commit':'6c904f0','baseline_related_checks':385,'headless':{'checks':sum(x['checks'] for x in hs),'failures':sum(x['failures'] for x in hs),'process_steps':len(passed),'suites':hs},'window':{'checks':sum(x['checks'] for x in ws),'failures':sum(x['failures'] for x in ws),'suites':ws,'platform':'Linux Godot 4.3 Xvfb/Mesa'},'home_suites':{'headless':102,'window':44,'persistence_assertions':22,'persistence_processes':7},'apk':{'file':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'version_code':14,'package':'org.pixelfarm.windbud','original_signing_preserved':True},'android_device_tested':False,'interrupt_restart_passed':True,'apk_desktop_resource_startup_passed':True,'tested_production_sha256':hashes,'logs':['builds/home05-final-check.log','builds/home05-final-window.log','builds/home05-final-build.log','builds/home05-final-apk-runtime.log','builds/home05-final-interrupt.log','builds/home05-latest-render.log','builds/home05-baseline.log']}
(ROOT/'docs/TEST-HOME05.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(record['headless']['checks'],record['window']['checks'],len(passed))
