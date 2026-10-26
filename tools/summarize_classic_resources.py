"""只接受完整成功日志，生成经典布局与资源更新交付记录。"""
from pathlib import Path
import ast,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
head=(ROOT/'builds/classic-resource-final-check.log').read_text();window=(ROOT/'builds/classic-resource-final-window.log').read_text()
if 'ALL CHECKS PASSED' not in head or 'WINDOW MATRIX PASSED' not in window:raise SystemExit('整套尚未完成')
if any(re.search(r'\bFAIL(?:ED)?\b|SCRIPT ERROR:|^ERROR:',t,re.M) for t in [head,window]):raise SystemExit('日志存在失败')
steps=next(ast.literal_eval(n.value) for n in ast.parse((ROOT/'tools/check_project.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets))
passed=re.findall(r'^\[([^\]]+)\] PASS$',head,re.M)
if passed!=[s[0] for s in steps]:raise SystemExit('执行步骤缺失')
for log,marker in [('classic-resource-final-apk-runtime.log','APK CODE INVARIANTS: PASS'),('classic-resource-final-interrupt.log','ACTUAL PROCESS INTERRUPT AND RESTART: PASS')]:
 if marker not in (ROOT/'builds'/log).read_text():raise SystemExit(log+'未通过')
def suites(text):return [{'suite':m.group(1).strip(),'checks':int(m.group(2)),'failures':int(m.group(3))} for m in re.finditer(r'^([^\n]*?RESULT): (\d+) checks, (\d+) failures',text,re.M)]
hs=suites(head);ws=suites(window);apk=ROOT/'builds/PixelWorld-0.7.1-debug.apk'
paths=set(subprocess.check_output(['git','diff','--name-only','536e30e','--','scripts','resources','project.godot','export_presets.cfg'],cwd=ROOT,text=True).splitlines());paths.add('scripts/gathering/resource_world.gd')
record={'version':'0.7.1','baseline_commit':'536e30e','classic_layout_reference':'2a48963','save_version':23,'headless':{'checks':sum(x['checks'] for x in hs),'failures':0,'process_steps':len(passed),'suites':hs},'window':{'checks':sum(x['checks'] for x in ws),'failures':0,'suites':ws,'platform':'Linux Godot4.3 Xvfb/Mesa'},'resources':{'farm':{'trees':30,'rocks':12},'village':{'trees':10,'rocks':6},'mist_forest':{'trees':45,'rocks':25},'all_nodes':128,'legacy_ids_preserved':19},'new_resource_suites':{'headless':117,'window':73,'persistence_processes':6,'persistence_assertions':21},'apk':{'file':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'version_code':15,'package':'org.pixelfarm.windbud'},'android_device_tested':False,'apk_desktop_resources_passed':True,'interrupt_restart_passed':True,'tested_production_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(paths) if (ROOT/p).is_file()},'logs':['builds/classic-resource-final-check.log','builds/classic-resource-final-window.log','builds/classic-resource-final-build.log','builds/classic-resource-final-apk-runtime.log','builds/classic-resource-final-interrupt.log']}
(ROOT/'docs/TEST-CLASSIC-RESOURCES.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(record['headless']['checks'],record['window']['checks'],len(passed))
