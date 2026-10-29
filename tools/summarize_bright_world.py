"""Collect actual bright-world renders, original-art audit and regression evidence."""
import ast
import hashlib
import json
from pathlib import Path
import re
import statistics

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/bright-world'
font = ImageFont.truetype(str(ROOT/'assets/ui/fonts/NotoSansCJK-Regular.ttc'), 24)
for name in ['farm_hud_1280x720', 'farm_full_spring', 'home', 'village', 'forest', 'house_level_4']:
    old = Image.open(OUT/'before'/(name+'.png')).convert('RGB')
    new = Image.open(OUT/'after'/(name+'.png')).convert('RGB')
    assert old.size == new.size
    canvas = Image.new('RGB', (old.width*2, old.height+44), '#f4ead1')
    canvas.paste(old, (0,44));canvas.paste(new, (old.width,44))
    draw = ImageDraw.Draw(canvas)
    draw.text((16,5), '调整前 · 原素材配色', font=font, fill='#5c4939')
    draw.text((old.width+16,5), '调整后 · 统一明亮田园配色', font=font, fill='#5c4939')
    canvas.save(OUT/('compare_'+name+'.png'))
canvas = Image.new('RGB', (3072,2136), '#f4ead1')
draw = ImageDraw.Draw(canvas)
for index, season in enumerate(['spring','summer','autumn','winter']):
    x, y = index%2*1536, index//2*1068
    canvas.paste(Image.open(OUT/'after'/('farm_full_'+season+'.png')).convert('RGB'), (x,y+44))
    draw.text((x+16,y+5), ['春 · 嫩绿','夏 · 浓绿','秋 · 暖金','冬 · 柔和雪色'][index], font=font, fill='#5c4939')
canvas.save(OUT/'four-seasons.png')

manifest = json.loads((ROOT/'assets/world_scheme_c/manifest.json').read_text())
for entry in manifest['copied_files']:
    assert hashlib.sha256((ROOT/'assets/world_scheme_c'/entry['path']).read_bytes()).hexdigest() == entry['sha256']
bright = json.loads((ROOT/'assets/world_scheme_c/bright_manifest.json').read_text())
for entry in bright['outputs']:
    source = Image.open(ROOT/entry['source']).convert('RGBA')
    image = Image.open(ROOT/entry['path']).convert('RGBA')
    assert source.size == image.size and source.getchannel('A').tobytes() == image.getchannel('A').tobytes()
    assert hashlib.sha256((ROOT/entry['path']).read_bytes()).hexdigest() == entry['sha256']

def image_stats(image):
    pixels = list(image.convert('RGB').getdata())
    light = [r*.2126+g*.7152+b*.0722 for r,g,b in pixels]
    return {'mean_rgb': [round(statistics.mean(p[c] for p in pixels),2) for c in range(3)],
            'srgb_weighted_luminance_0_255': round(statistics.mean(light),2),
            'luminance_stddev': round(statistics.pstdev(light),2), 'unique_colours': len(set(pixels))}

metrics = {}
for phase in ['before','after']:
    image = Image.open(OUT/phase/'farm_hud_1280x720.png')
    metrics[phase] = {'grass_patch': image_stats(image.crop((140,380,250,420))),
                      'road_patch': image_stats(image.crop((530,294,610,308)))}
old = Image.open(OUT/'before/farm_hud_1280x720.png')
new = Image.open(OUT/'after/farm_hud_1280x720.png')
ui_same = old.crop((24,16,150,68)).tobytes() == new.crop((24,16,150,68)).tobytes()
assert ui_same
tree = ast.parse((ROOT/'tools/check_project.py').read_text())
steps = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node,ast.Assign)
             and any(isinstance(target,ast.Name) and target.id=='steps' for target in node.targets))
suites = []
for name,_ in steps:
    text = (ROOT/'builds'/(name+'.log')).read_text()
    assert not any(marker in text for marker in ['SCRIPT ERROR:', 'ERROR:', 'FAIL:', 'instances leaked']), name
    results = re.findall(r'RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures', text, re.I)
    suites.append({'name': name, 'checks': sum(int(n) for n,_ in results), 'failures': sum(int(n) for _,n in results)})
captures = {phase: json.loads((OUT/phase/'manifest.json').read_text()) for phase in ['before','after']}
assert all(record['saved'] for report in captures.values() for record in report['captures'])
palette = json.loads((ROOT/'resources/presentation/world_palette.json').read_text())
packages = []
for name in ['PixelWorld-0.8.0-Windows-x64.zip', 'PixelWorld-0.8.0-debug.apk']:
    path = ROOT/'builds'/name
    packages.append({'name': name, 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
report = {'baseline': 'f5a02037689792267bf059226858b593ccee205b',
          'source_assets': len(manifest['assets']), 'original_files_unchanged': len(manifest['copied_files']),
          'palette_colours': sum(len(ramp) for ramp in palette['ramps'].values()),
          'derived_pngs_geometry_and_alpha_verified': len(bright['outputs']),
          'metrics': metrics, 'hud_title_pixels_unchanged': ui_same,
          'metrics_scope': 'Same fixed scene, daytime, X11 window, sRGB pixel values; not physical lighting measurements.',
          'full_regression': {'processes': len(suites), 'checks': sum(s['checks'] for s in suites), 'failures': sum(s['failures'] for s in suites), 'suites': suites},
          'window_captures': {phase: len(data['captures']) for phase,data in captures.items()},
          'packages': packages, 'save_schema': 27, 'android_version_code': 27,
          'android_device_tested': False, 'windows_native_tested': False}
(OUT/'results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps({key: value for key,value in report.items() if key!='full_regression'}, ensure_ascii=False, indent=2))
print('Full regression:', report['full_regression']['processes'], 'processes,',report['full_regression']['checks'], 'checks')
