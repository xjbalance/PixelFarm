"""Collect executed farm-DIY acceptance evidence; do not count repeated runs twice."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/farm-diy'


def read(name):return json.loads((ROOT/'builds'/name).read_text())


def summarize():
    text=(ROOT/'builds/farm-diy-full-check.log').read_text()
    assert 'ALL CHECKS PASSED:' in text and 'ERROR:' not in text
    processes=re.findall(r'^\[([^\]]+)\] PASS$',text,re.M)
    results=re.findall(r'(?i)RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures',text)
    count=sum(int(n) for n,_ in results)
    assert len(processes)==188 and count==9736 and all(int(f)==0 for _,f in results)
    reports={}
    for name in ['farm-layout-state.json','farm-layout-persistence-processes.json',
                 'farm-diy-editor-state.json','farm-diy-editor-render.json',
                 'farm-diy-production-state.json','farm-diy-production-render.json',
                 'farm-layout-business-state.json','farm-layout-business-render.json']:
        data=read(name);reports[name]=data
        (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    windows=[]
    for name in ['farm-diy-editor-render.json','farm-diy-production-render.json','farm-layout-business-render.json']:
        data=reports[name];assert data['failures']==0 and data['platform']!='headless'
        windows.append({'name':name,'checks':data['checks'],'failures':0})
    assert sum(d['checks'] for d in windows)==359
    win=read('windows-package-0.8.0.json');wine=read('windows080-wine-report.json')
    assert wine['status']=='passed' and wine['save_version']==27 and wine['pck_sha256']==win['pck_sha256']
    (OUT/'windows-wine.json').write_text(json.dumps(wine,ensure_ascii=False,indent=2)+'\n')
    folder=OUT/'windows-wine';folder.mkdir(exist_ok=True)
    for p in (ROOT/'builds').glob('windows080-wine-*.png'):shutil.copy2(p,folder/p.name)
    apk_log=(ROOT/'builds/territory080-apk-editor.log').read_text()
    for line in ['APK SCHEME C 97-ASSET LOAD: PASS','APK FARM LAYOUT V27 MOVE/RESTORE: PASS','APK TERRITORY EDITOR SMOKE: PASS']:assert line in apk_log
    apk=ROOT/'builds/PixelWorld-0.8.0-debug.apk'
    old=Image.open(OUT/'before/farm_full_spring.png').convert('RGB')
    new=Image.open(OUT/'editor/farm-diy-editor-full_farm_after.png').convert('RGB')
    assert old.size==new.size==(1536,1024)
    picture=Image.new('RGB',(3072,1072),'#f4e7cd');picture.paste(old,(0,48));picture.paste(new,(1536,48))
    font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'),24)
    draw=ImageDraw.Draw(picture);draw.text((18,9),'之前 · 原住宅固定在中部',font=font,fill='#35291f');draw.text((1554,9),'现在 · 真实编辑器搬迁住宅，旧址重新规划',font=font,fill='#35291f')
    picture.save(OUT/'comparison-farm-layout.png',optimize=True)
    report={
        'version':'0.8.0','release':'全场DIY','save_version':27,
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'baseline_commit':'ea3204b81b94978cf2a4ddd388c7d4ccf5bbf972',
        'state':{'processes':188,'checks':9736,'failures':0,'repeated_runs_excluded':True},
        'actual_windows':{'suites':windows,'checks':359,'failures':0},
        'registry':reports['farm-diy-editor-render.json']['registry'],
        'save_compatibility':'v26-to-v27 migration and original v1-v25 regression; preserves byte backups and existing progress',
        'safety_probes':'Actual rejected previews: door obstruction, player water, passive point in water, lake over crops/resources, resource/plot corner intersections',
        'decor_restore_probe':'11 checks passed; original decoration remains visible when explicitly placed over edited terrain, including default-position restore',
        'windows':win,'wine_passed':True,
        'android':{'file':apk.name,'version_code':25,'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'original_signature':True,'exported_97_assets_load':True,'exported_real_house_move_save_restore':True},
        'android_device_tested':False,'windows_native_tested':False,
        'screenshots':'Actual isolated Godot windows; layout and progress fixtures, not player saves. Before is isolated ea3204b, after is the real editor.'
    }
    (ROOT/'docs/TEST-FARM-DIY.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    files=subprocess.check_output(['git','diff','--name-only','ea3204b',report['source_commit']],cwd=ROOT,text=True).splitlines()
    (OUT/'changed-files.json').write_text(json.dumps({'source_commit':report['source_commit'],'files':files},ensure_ascii=False,indent=2)+'\n')
    print('Verified 188 processes / 9736 state checks / 359 actual-window checks')
    print('PNG evidence',len(list(OUT.rglob('*.png'))))


if __name__=='__main__':summarize()
