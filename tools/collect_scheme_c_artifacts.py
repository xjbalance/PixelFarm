"""整理实际Godot窗口角色画面，不重新绘制或伪造运行截图。"""
from pathlib import Path
import json,shutil

ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'docs/scheme-c-game';out.mkdir(exist_ok=True);(out/'.gdignore').touch()
record=json.loads((ROOT/'builds/scheme-c-game-render.json').read_text())
if record['failures']: raise SystemExit('Scheme C game window test failed')
for frame in record['captures']:
    source=ROOT/frame['path'].removeprefix('res://')
    target=out/(frame['name']+'.png');shutil.copyfile(source,target);frame['file']=str(target.relative_to(ROOT))
record['note']='Actual Linux Godot4.3 window frames. Companion display fixtures meet the existing 520-plant unlock state; they do not claim a new-player story shortcut.'
(out/'screenshots.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
for suite in ['star','legend','river']:
    shutil.copyfile(ROOT/f'builds/scheme-c-female-{suite}-evidence.json',out/f'female-{suite}-evidence.json')
shutil.copyfile(ROOT/'builds/scheme-c-female-regression-summary.json',out/'female-regression-summary.json')
selection=json.loads((ROOT/'builds/character-select-render.json').read_text())
if selection['failures']: raise SystemExit('Character selection window test failed')
dest=ROOT/'docs/scheme-c-selection';dest.mkdir(exist_ok=True);(dest/'.gdignore').touch()
for raw in selection['captures']:
    source=ROOT/raw.removeprefix('res://');shutil.copyfile(source,dest/source.name.removeprefix('character-select-'))
(dest/'screenshots.json').write_text(json.dumps(selection,ensure_ascii=False,indent=2)+'\n')
print(len(record['captures']),'game frames,',len(selection['captures']),'selection frames')
