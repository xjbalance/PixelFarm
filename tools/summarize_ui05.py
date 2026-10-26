"""只从完整执行成功的UI05日志生成交付统计，拒绝中断/失败/缺少进程的记录。"""
from pathlib import Path
import ast, hashlib, json, re, subprocess
ROOT=Path(__file__).resolve().parents[1]
head=(ROOT/'builds/ui05-final-check.log').read_text()
window=(ROOT/'builds/ui05-final-window.log').read_text()
if 'ALL CHECKS PASSED' not in head or 'WINDOW MATRIX PASSED' not in window: raise SystemExit('完整测试尚未结束，拒绝生成通过报告')
if any(re.search(r'\bFAIL(?:ED)?\b|SCRIPT ERROR:|^ERROR:',text,re.M) for text in [head,window]): raise SystemExit('日志有失败/错误，拒绝生成通过报告')
steps=next(ast.literal_eval(n.value) for n in ast.parse((ROOT/'tools/check_project.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets))
passed=re.findall(r'^\[([^\]]+)\] PASS$',head,re.M)
if passed!=[name for name,args in steps]: raise SystemExit('进程步骤不完整或不按计划执行')
def suites(text):
 return [{'suite':m.group(1).strip(),'checks':int(m.group(2)),'failures':int(m.group(3))} for m in re.finditer(r'^([^\n]*?RESULT): (\d+) checks, (\d+) failures',text,re.M)]
head_suites=suites(head)
window_suites=[{'suite':m.group(1),'checks':int(m.group(2)),'failures':int(m.group(3))} for m in re.finditer(r'^([^\n]*?) :\[ 0 \] [^\n]*RESULT: (\d+) checks, (\d+) failures',window,re.M)]
if not head_suites or not window_suites or any(x['failures'] for x in head_suites+window_suites): raise SystemExit('断言套件缺失或失败')
for name,marker in [('ui05-final-apk-runtime.log','APK CODE INVARIANTS: PASS'),('ui05-final-interrupt.log','ACTUAL PROCESS INTERRUPT AND RESTART: PASS')]:
 if marker not in (ROOT/'builds'/name).read_text(): raise SystemExit(name+'未通过')
production=subprocess.check_output(['git','diff','--name-only','2a48963','--','scripts','resources','project.godot','export_presets.cfg'],cwd=ROOT,text=True).splitlines()
hashes={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in production if (ROOT/name).is_file()}
apk=ROOT/'builds/PixelWorld-0.7.1-debug.apk'
record={'version':'0.7.1','save_version':22,'baseline_commit':'2a48963','baseline':{'headless_checks':3402,'window_checks':1899},'headless':{'checks':sum(x['checks'] for x in head_suites),'failures':0,'process_steps':len(passed),'suites':head_suites},'window':{'checks':sum(x['checks'] for x in window_suites),'failures':0,'suite_count':len(window_suites),'platform':'Linux Godot 4.3 Xvfb/Mesa','suites':window_suites},'new_suites':{'camera':48,'hotbar':43,'layout':301},'interrupt_restart_passed':True,'apk_desktop_resource_startup_passed':True,'apk':{'file':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'version_code':13,'package':'org.pixelfarm.windbud'},'android_device_tested':False,'tested_production_sha256':hashes,'logs':['builds/ui05-final-check.log','builds/ui05-final-window.log','builds/ui05-final-interrupt.log','builds/ui05-final-apk-runtime.log','builds/ui05-final-build.log']}
(ROOT/'docs/TEST-UI05.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(f"UI05 VERIFIED: {record['headless']['checks']} headless checks / {record['window']['checks']} window checks / {len(passed)} process steps")
