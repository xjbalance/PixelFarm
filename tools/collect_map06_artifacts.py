"""整理真实Godot地图窗口帧；不生成或伪造游戏截图。"""
from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
record = json.loads((ROOT / 'builds/atlas-ui-render-evidence.json').read_text())
if record['failures']:
    raise SystemExit('图纸窗口检查未通过')
out = ROOT / 'docs/parchment-map'
out.mkdir(exist_ok=True)
(out / '.gdignore').touch()
for frame in record['captures']:
    src = ROOT / frame['path'].removeprefix('res://')
    dst = out / (frame['name'] + '.png')
    shutil.copyfile(src, dst)
    frame['file'] = str(dst.relative_to(ROOT))
for kind in ['before', 'after']:
    shutil.copyfile(ROOT / f'builds/atlas-core-world-bridge-{kind}.png', out / f'bridge-{kind}.png')
record['note'] = 'Actual Linux Godot 4.3 window frames; no Android device acceptance.'
(out / 'screenshots.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print('Actual atlas frames:', len(record['captures']), '+ 2 bridge states')
