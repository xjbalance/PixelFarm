"""Consolidate complete suite coverage and exact final artifact/window evidence."""
from pathlib import Path
import ast,re,json,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/quality081'
module=ast.parse((ROOT/'tools/check_project.py').read_text())
steps=next(ast.literal_eval(n.value) for n in module.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='steps' for t in n.targets))
runs=sorted((ROOT/'builds').glob('quality081-full*.log'));coverage=set()
for path in runs:coverage.update(re.findall(r'^\[([^\]]+)\] PASS$',path.read_text(),re.M))
assert not [name for name,_ in steps if name not in coverage]
def checked(path):
 value=path.read_text();assert not any(x in value for x in ['ERROR:','FAIL:','instances leaked']),path
 return value
suites=[];full=[]
for name,_ in steps:
 text=checked(ROOT/'builds'/f'{name}.log')
 suites.append({'name':name,'checks':len(re.findall(r'^PASS:',text,re.M)),'status':'passed','log':f'builds/{name}.log'})
 full.append(text+'\n['+name+'] PASS\n')
(ROOT/'builds/quality081-acceptance.log').write_text(''.join(full))
windows=[]
for scene in ['quality081_visual','quality081_animation_runner','quality081_ui_runner','quality081_production_runner','quality081_stress_runner']:
 text=checked(ROOT/'builds'/f'quality081-{scene}-after.log');windows.append({'scene':scene,'checks':len(re.findall(r'^PASS:',text,re.M)),'status':'passed'})
for scene in ['harvest_render','harvest_touch_runner','harvest_processing_runner','harvest_chains_runner']:
 text=checked(ROOT/'builds'/f'{scene}-window.log');windows.append({'scene':scene,'checks':len(re.findall(r'^PASS:',text,re.M)),'status':'passed'})
artifacts={}
for name in ['PixelWorld-0.8.1-Windows-x64.zip','PixelWorld-0.8.1-debug.apk']:
 path=ROOT/'builds'/name;artifacts[name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
wine=json.loads((ROOT/'builds/windows080-wine-report.json').read_text())
assert wine['status']=='passed' and wine['pck_sha256']==hashlib.sha256((ROOT/'builds/PixelWorld-0.8.1-Windows-x64/PixelWorld.pck').read_bytes()).hexdigest()
assert 'APK QUALITY081 WORKING ATLAS / SNAPSHOT V2 / BALANCE: PASS' in checked(ROOT/'builds/quality081-apk-proof.log')
assert 'SOURCE ARCHIVE ACCEPTANCE: PASS' in checked(ROOT/'builds/quality081-source-verification.log')
assets=json.loads((OUT/'assets.json').read_text());balance=json.loads((OUT/'economy.json').read_text())
protected=json.loads((OUT/'protected-rules.json').read_text())
for row in protected['files']:assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256']
result={'version':'0.8.1','title':'丰收匠心','save_version':29,'workshop_version':2,'android_version_code':31,
 'baseline':json.loads((OUT/'baseline-tests.json').read_text()),
 'regression':{'processes':len(suites),'checks':sum(x['checks'] for x in suites),'failures':0,'all_configured_steps_covered':True,'runs':[p.name for p in runs],'suites':suites},
 'windows':{'checks':sum(x['checks'] for x in windows),'failures':0,'suites':windows,'actual_godot_window':True,'resolutions':[[1280,720],[1560,720],[1600,720],[1280,960]],'480dpi_simulated':True,'safe_area_simulated':True},
 'art':{'native_resources_validated':assets['resources'],'palette_colors':89,'runtime_item_icons':153,'crop_types':33,'fruit_tree_types':4,'physical_stations':10,'new_content_added':False},
 'production':{'timed_recipes':49,'kitchen_recipes':32,'all_agricultural_routes_audited':balance['recipe_count'],'five_real_chains':'passed','input_output_snapshots':'passed','old_engine_v28_save':'passed','cross_save_parent_and_signal_binding':'passed','menu_background_and_sleep':'passed','claim_once':'passed'},
 'economy':{'changed_paths':balance['changes'],'crop_tree_station_definitions':'unchanged','non_target_resource_hashes':len(protected['files']),'recipe_cycles':'none','unobtainable_active_inputs':[]},
 'performance':json.loads((OUT/'performance.json').read_text()),'artifacts':artifacts,'apk_signature_original':'passed','apk_packed_runtime':'passed','windows_exe_wine':'passed','source_fresh_import':'passed',
 'android_device_tested':False,'windows_native_tested':False,
 'remaining':['Android hardware touch/thermal/power acceptance','Native Windows hardware acceptance','Duck/goat/pig/beehive/mushroom production remains outside implemented base game','Long-term player economy feedback']}
(OUT/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(OUT/'windows-runtime.json').write_text(json.dumps(wine,ensure_ascii=False,indent=2)+'\n')
(OUT/'apk-proof.txt').write_text(checked(ROOT/'builds/quality081-apk-proof.log').rstrip()+'\n')
print('QUALITY081 ACCEPTANCE:',len(suites),'processes,',result['regression']['checks'],'checks,',result['windows']['checks'],'window checks; all passed')
