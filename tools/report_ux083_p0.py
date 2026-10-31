"""Collect executed P0 task evidence; animations use actual Godot window samples."""
from pathlib import Path
import argparse, ast, hashlib, json, re
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/ux083/p0'
BUILD = ROOT / 'builds'
parser = argparse.ArgumentParser()
parser.add_argument('--allow-incomplete', action='store_true')
args = parser.parse_args()
module = ast.parse((ROOT / 'tools/check_project.py').read_text())
steps = ast.literal_eval(next(n.value for n in module.body if isinstance(n, ast.Assign)
    and any(isinstance(t, ast.Name) and t.id == 'steps' for t in n.targets)))
run_logs = [BUILD / name for name in ['ux083-p0-full-regression-final.log',
    'ux083-p0-full-regression-resume.log', 'ux083-p0-full-regression-resume2.log']]
run_text = '\n'.join(p.read_text() for p in run_logs if p.exists())
passed = set(re.findall(r'^\[([^\]]+)\] PASS$', run_text, re.M))
records = []
for name, _ in steps:
    p = BUILD / (name + '.log')
    s = p.read_text() if p.exists() else ''
    records.append({'process': name, 'executed_in_this_run': name in passed,
        'checks': sum(int(a) for a, _ in re.findall(r'RESULT[^\n]*?:\s*(\d+) checks,\s*(\d+) failures', s)),
        'errors': any(t in s for t in ['SCRIPT ERROR:', 'ERROR:', 'FAIL:', 'instances leaked'])})
complete = 'ALL CHECKS PASSED:' in run_text and all(r['executed_in_this_run'] and not r['errors'] for r in records)
before = json.loads((OUT / 'before-tasks.json').read_text())
after = json.loads((OUT / 'after-window-tasks.json').read_text())
geometry = json.loads((OUT / 'after-window-geometry.json').read_text())
assert after['failures'] == 0 and not after['business_mismatches'] and geometry['failures'] == 0
window_checks = []
for label in ['task', 'geometry', 'lifecycle']:
    p = BUILD / f'ux083-p0-proof-{label}-window.log'
    s = p.read_text()
    result = re.search(r'RESULT: (\d+) checks, (\d+) failures', s)
    assert result and int(result[2]) == 0 and 'ERROR:' not in s, p
    window_checks.append({'suite': label, 'checks': int(result[1]), 'failures': 0, 'log': p.name})

font = ImageFont.truetype(str(ROOT / 'assets/ui/fonts/NotoSansCJK-Regular.ttc'), 26)
def compare(left_path, right_path, name, labels):
    left = Image.open(left_path).convert('RGB'); right = Image.open(right_path).convert('RGB')
    picture = Image.new('RGB', (left.width + right.width + 20, max(left.height, right.height) + 64), '#eddfbd')
    picture.paste(left, (0, 64)); picture.paste(right, (left.width + 20, 64))
    draw = ImageDraw.Draw(picture)
    draw.text((16, 14), labels[0], font=font, fill='#634c3b')
    draw.text((left.width + 36, 14), labels[1], font=font, fill='#634c3b')
    picture.save(OUT / name)

compare(OUT/'before/old_letter_marker-tap-result.png', OUT/'after/old_letter_marker-tap-interaction.png',
    'letter-marker-comparison.png', ['修复前：标记被当成墙边地面', '修复后：走近原书桌，打开原剧情对话'])

clips = []
for name in ['welcome-tap', 'mill_records-tap', 'gather_tree-tap', 'narrow-passage-tap', 'narrow-passage-joystick']:
    files = sorted((OUT / 'after').glob(name + '-frame-*.png'))
    if len(files) < 2: continue
    pictures = [Image.open(p).convert('RGB').resize((640, 360), Image.NEAREST) for p in files]
    timings = [50] * len(pictures)
    interaction = OUT / 'after' / (name + '-interaction.png')
    if interaction.exists():
        pictures.append(Image.open(interaction).convert('RGB').resize((640, 360), Image.NEAREST))
        timings.append(1200)
    target = OUT / (name + '.gif')
    pictures[0].save(target, save_all=True, append_images=pictures[1:], duration=timings,
        loop=0, disposal=2, optimize=False)
    clips.append({'file': target.name, 'frames': len(pictures), 'actual_window': True,
        'note': '640x360 nearest-neighbour reduction of actual window samples; no synthetic motion or altered game camera'})

pairs = {}
for row in after['cases']: pairs.setdefault(row['task'], {})[row['mode']] = row
table = ['| 任务或操作 | 摇杆 / 点击 | 金币变化（两者相同） | 物品变化（两者相同） |', '|---|---|---:|---|']
for name, pair in pairs.items():
    joy, tap = pair['joystick'], pair['tap']
    assert joy['success'] and tap['success'] and joy['after'] == tap['after'], name
    old, new = tap['before'], tap['after']
    changes = [f'{item} {int(new["items"].get(item,0)-old["items"].get(item,0)):+d}'
        for item in sorted(old['items'].keys() | new['items'].keys()) if old['items'].get(item,0) != new['items'].get(item,0)]
    table.append(f'| `{name}` | 通过 / 通过 | {new["coins"]-old["coins"]:+d} | '+('、'.join(changes) or '无')+' |')
(OUT / 'task-outcomes.md').write_text('\n'.join(table) + '\n')
result = {'baseline': '2d427f2', 'save_version': 30, 'complete_regression': complete,
    'processes': len(records), 'passed_processes': sum(r['executed_in_this_run'] and not r['errors'] for r in records),
    'checks': sum(r['checks'] for r in records if r['executed_in_this_run']), 'records': records,
    'original_business_mismatches': before['business_mismatches'], 'paired_task_cases': len(pairs),
    'window_checks': window_checks, 'window_total': sum(r['checks'] for r in window_checks),
    'clips': clips, 'android_physical_device_tested': False,
    'gameplay_sources': {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in [
        'scripts/navigation/navigation_manager.gd', 'scripts/navigation/auto_move_controller.gd',
        'scripts/input/interaction_resolver.gd', 'scripts/world/story_point.gd', 'scripts/core/main.gd', 'scripts/core/audio.gd']}}
(OUT / 'results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print('P0 evidence:', result['passed_processes'], '/', len(records), 'processes;', len(pairs), 'paired tasks;', result['window_total'], 'window checks')
if not complete and not args.allow_incomplete: raise SystemExit('Complete regression has not finished successfully.')
