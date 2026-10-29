"""仅由完整成功运行的实际日志生成农场/羊皮纸地图整合验收记录。"""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
head = (ROOT / 'builds/map06-final-check.log').read_text()
window = (ROOT / 'builds/map06-final-window.log').read_text()
error = re.compile(r'\bFAIL(?:ED)?\b|SCRIPT ERROR:|^ERROR:|instances leaked', re.M)
if 'ALL CHECKS PASSED' not in head or 'WINDOW MATRIX PASSED' not in window:
    raise SystemExit('完整回归尚未全部通过')
if error.search(head) or error.search(window):
    raise SystemExit('最终日志仍有错误')
steps = next(ast.literal_eval(n.value) for n in ast.parse((ROOT / 'tools/check_project.py').read_text()).body
             if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'steps' for t in n.targets))
passed = re.findall(r'^\[([^\]]+)\] PASS$', head, re.M)
if passed != [step[0] for step in steps]:
    raise SystemExit('计划进程未完整执行')
for file, marker in [('map06-final-apk-runtime.log', 'APK CODE INVARIANTS: PASS'),
                     ('map06-final-interrupt.log', 'ACTUAL PROCESS INTERRUPT AND RESTART: PASS')]:
    log = (ROOT / 'builds' / file).read_text()
    if marker not in log or error.search(log):
        raise SystemExit(file + '未通过')

def suites(log):
    return [{'suite': m[1], 'checks': int(m[2]), 'failures': int(m[3])}
            for m in re.finditer(r'^([^\n]*?RESULT): (\d+) checks, (\d+) failures', log, re.M)]

hs, ws = suites(head), suites(window)
paths = set(subprocess.check_output(['git', 'diff', '--name-only', '0ac1b78', '--',
                                    'scripts', 'assets', 'resources', 'project.godot', 'export_presets.cfg'],
                                   cwd=ROOT, text=True).splitlines())
for folder in ['scripts/maps', 'assets/maps']:
    paths.update(str(p.relative_to(ROOT)) for p in (ROOT / folder).rglob('*') if p.is_file())
apk = ROOT / 'builds/PixelWorld-0.7.1-debug.apk'
record = {
    'version': '0.7.1', 'save_version': 24, 'baseline_commit': '0ac1b78',
    'independent_commits': {'sale_quantity': 'd973328', 'farm_visual_sample': 'cac470b'},
    'headless': {'checks': sum(x['checks'] for x in hs), 'failures': 0, 'process_steps': len(passed), 'suites': hs},
    'window': {'checks': sum(x['checks'] for x in ws), 'failures': 0, 'suite_count': len(ws), 'suites': ws,
               'platform': 'Linux Godot 4.3 Xvfb/Mesa'},
    'new_suites': [x for x in hs + ws if any(label in x['suite'] for label in ['SALE QUANTITY', 'FARM VISUAL 06', 'ATLAS'])],
    'apk': {'file': apk.name, 'bytes': apk.stat().st_size, 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
            'version_code': 17, 'package': 'org.pixelfarm.windbud'},
    'android_device_tested': False, 'interrupt_restart_passed': True, 'apk_desktop_resources_passed': True,
    'tested_production_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
                                 for p in sorted(paths) if (ROOT / p).is_file()},
    'logs': ['builds/map06-final-check.log', 'builds/map06-final-window.log', 'builds/map06-final-build.log',
             'builds/map06-final-apk-runtime.log', 'builds/map06-final-interrupt.log']
}
(ROOT / 'docs/TEST-MAP06.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(record['headless']['checks'], record['window']['checks'], len(passed))
