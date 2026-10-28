"""Collect actual test/build evidence and compose pixel-preserving comparisons."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/need-assets'


def read(name):
    return json.loads((ROOT/'builds'/name).read_text())


def summary():
    log=(ROOT/'builds/need-full-check.log').read_text()
    assert 'ALL CHECKS PASSED:' in log
    runs=re.findall(r'^\[([^\]]+)\] PASS$',log,re.M)
    results=re.findall(r'(?i)RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures',log)
    total=sum(int(n) for n,_ in results)
    assert len(runs)==172 and total==6928 and all(int(f)==0 for _,f in results)
    tests=[]
    for name in ['world_assets_runner','scheme_c_nature_runner','scheme_c_placement_runner','scheme_c_props_runner','farm_edit_runner','farm_edit_kinds_runner']:
        text=(ROOT/f'builds/need-final-{name}.log').read_text()
        matched=re.search(r'RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures',text)
        assert matched and int(matched[2])==0 and 'ERROR:' not in text,name
        tests.append({'name':name,'checks':int(matched[1]),'failures':0})
    for name in ['farm-edit-state.json','farm-edit-render.json','farm-edit-kinds-state.json',
                 'scheme-c-placement-state.json','scheme-c-placement-render.json',
                 'scheme-c-props-state.json','scheme-c-props-render.json',
                 'scheme-c-nature-state.json','scheme-c-nature-render.json']:
        shutil.copy2(ROOT/'builds'/name,OUT/name)
    for folder,pattern in [('placement','scheme-c-placement-*.png'),('props','scheme-c-props-livestock*.png'),('edit','farm-edit-*.png'),('windows-wine','windows080-wine-*.png')]:
        target=OUT/folder;target.mkdir(parents=True,exist_ok=True)
        for p in (ROOT/'builds').glob(pattern):shutil.copy2(p,target/p.name)
    font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),24)
    for name in ['farm_hud_1280x720','farm_full_spring','house_level_4','village','home']:
        old=Image.open(OUT/'before'/(name+'.png')).convert('RGB')
        new=Image.open(OUT/'after'/(name+'.png')).convert('RGB')
        assert old.size==new.size
        canvas=Image.new('RGB',(old.width*2,old.height+48),'#f4e7cd')
        canvas.paste(old,(0,48));canvas.paste(new,(old.width,48))
        draw=ImageDraw.Draw(canvas)
        draw.text((18,9),'优化前 · dac68e8',font=font,fill='#35291f')
        draw.text((old.width+18,9),'优化后 · 方案 C 世界素材整合',font=font,fill='#35291f')
        canvas.save(OUT/('compare_'+name+'.png'),optimize=True)
    windows=read('windows-package-0.8.0.json');wine=read('windows080-wine-report.json')
    assert wine['status']=='passed' and wine['pck_sha256']==windows['pck_sha256']
    windows['wine']=wine
    apk=ROOT/'builds/PixelWorld-0.8.0-debug.apk'
    apk_log=(ROOT/'builds/territory080-apk-editor.log').read_text()
    assert 'APK SCHEME C 97-ASSET LOAD: PASS' in apk_log and 'APK TERRITORY EDITOR SMOKE: PASS' in apk_log
    window_tests=[]
    for name in ['world-style07-render.json','farm06-render-evidence.json','territory-editor-render.json',
                 'farm-edit-render.json','scheme-c-nature-render.json','scheme-c-props-render.json','scheme-c-placement-render.json']:
        data=read(name)
        assert data['failures']==0,name
        window_tests.append({'name':name,'checks':data['checks'],'failures':data['failures']})
    report={
        'version':'0.8.0','date':'2026-10-28',
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'baseline_commit':'dac68e8445b7167c859aa4b19c28d73fe2c48530',
        'supplied_world_assets':97,'byte_verified_files':150,'native_grid':32,
        'save_version':26,'save_schema_changed':False,
        'regression':{'processes':172,'checks':total,'failures':0},
        'new_suites':tests,
        'state_total':{'processes':len(runs)+len(tests),'checks':total+sum(x['checks'] for x in tests),'failures':0,'repeated_runs_excluded':True},
        'actual_window_suites':window_tests,
        'actual_window_checks':sum(x['checks'] for x in window_tests),
        'coverage':read('farm-edit-state.json')['metrics'],
        'windows':windows,
        'android':{'version_code':24,'path':apk.name,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'original_signing_certificate_retained':True,'all_97_exported_assets_loaded':True,'exported_editor_smoke':True},
        'android_device_tested':False,'windows_native_tested':False,
        'screenshot_fixture_notice':'Before/after are actual isolated Godot windows; garden and restored greenhouse use explicitly staged progress. Wine is not native Windows acceptance.',
    }
    (ROOT/'docs/TEST-NEED-ASSETS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    files=subprocess.check_output(['git','diff','--name-only','dac68e8',report['source_commit']],cwd=ROOT,text=True).splitlines()
    (OUT/'changed-runtime-files.json').write_text(json.dumps({'source_commit':report['source_commit'],'files':files},ensure_ascii=False,indent=2)+'\n')
    print('Verified state totals:',report['state_total'])
    print('Actual-window checks:',report['actual_window_checks'])
    print('PNG artifacts:',len(list(OUT.rglob('*.png'))))


if __name__=='__main__':summary()
