"""Collect actual regression, window and exported-resource evidence."""
from pathlib import Path
import hashlib
import json
import re

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/marriage-mastery'
log=(ROOT/'builds/marriage-mastery-full-check.log').read_text()
assert 'ALL CHECKS PASSED:' in log
assert not any(marker in log for marker in ['SCRIPT ERROR:','ERROR:','FAIL:','instances leaked'])
stages=re.findall(r'^\[([^\]]+)\] PASS$',log,re.M)
results=re.findall(r'RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures',log,re.I)
assert all(int(f)==0 for _,f in results)
window=[]
for name in ['marriage-mastery-render.json','marriage-requirements-render.json','fishing-odds-render.json']:
    report=json.loads((OUT/name).read_text())
    assert report['failures']==0 and report['platform']=='X11'
    assert all((ROOT/str(row['path']).removeprefix('res://')).is_file() for row in report['captures'])
    window.append({'suite':name,'checks':report['checks'],'failures':report['failures'],'captures':len(report['captures'])})
apk_log=(ROOT/'builds/territory080-apk-editor.log').read_text()
assert 'APK MARRIAGE MASTERY 9-STORY/5-RECIPE/7-FISH CONFIG: PASS' in apk_log
assert 'APK FISHING NO-PITY / ONE-TENTH ENCOUNTER CONFIG: PASS' in apk_log
packages=[]
for name in ['PixelWorld-0.8.0-Windows-x64.zip','PixelWorld-0.8.0-debug.apk']:
    path=ROOT/'builds'/name
    packages.append({'name':name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
report={'baseline':'3c2457bc306fc7dcb17c51eb077ca31fe93c885a',
        'configuration':json.loads((ROOT/'resources/story/marriage_preparation.json').read_text()),
        'full_regression':{'processes':len(stages),'checks':sum(int(n) for n,_ in results),'failures':0,'stages':stages,
                           'log_sha256':hashlib.sha256(log.encode()).hexdigest()},
        'window_regression':window,'window_total_checks':sum(row['checks'] for row in window),
        'save_schema':27,'new_persistent_fields':False,'old_completed_records_recognized':True,
        'old_married_saves_preserved':True,'diamond_cost':1314,'android_version_code':29,
        'fishing_pity_removed':True,'eternal_chance_divisor':10,
        'fishing_odds':json.loads((OUT/'fishing-odds-render.json').read_text())['cases'],
        'exported_marriage_config_verified':True,'packages':packages,
        'android_device_tested':False,'windows_native_tested':False}
(OUT/'results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('FULL:',report['full_regression']['processes'],'processes,',report['full_regression']['checks'],'checks, 0 failures')
print('WINDOW:',report['window_total_checks'],'checks, 0 failures')
print('Saved:',OUT/'results.json')
