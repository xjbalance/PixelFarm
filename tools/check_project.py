"""标准库测试入口：Godot 4.3 导入、集成测试、独立进程存档恢复及主场景启动。"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot', default=None, help='Godot 4.3 Standard executable')
args = parser.parse_args()
portable = ROOT / '.tools/Godot_v4.3-stable_linux.x86_64'
godot = args.godot or shutil.which('godot') or shutil.which('godot4') or (str(portable) if portable.exists() else None)
if not godot:
    raise SystemExit('未发现 Godot。用 --godot 指定 Godot 4.3 Standard 可执行文件。')
version = subprocess.check_output([godot, '--version'], text=True).strip()
if not version.startswith('4.3.'):
    raise SystemExit('本工程要求 Godot 4.3，当前为 ' + version)
logs = ROOT/'builds'
logs.mkdir(exist_ok=True)
steps = [
    ('import', ['--import']),
    ('sleep', ['--fixed-fps','60','res://tests/sleep_runner.tscn']),
    ('integration', ['res://tests/runner.tscn']),
    ('mining', ['--fixed-fps','60','res://tests/mining_runner.tscn']),
    ('star', ['--fixed-fps','60','res://tests/star_runner.tscn']),
    ('legend', ['--fixed-fps','60','res://tests/legend_runner.tscn']),
    ('stability', ['--fixed-fps','60','res://tests/stability_runner.tscn']),
    ('river', ['--fixed-fps','60','res://tests/river_runner.tscn']),
    ('aquaculture', ['--fixed-fps','60','res://tests/aquaculture_runner.tscn']),
    ('seasons-a', ['--fixed-fps','60','res://tests/seasons_a_runner.tscn']),
    ('control-recovery', ['--fixed-fps','60','res://tests/control_recovery_runner.tscn']),
    ('fishing-b', ['--fixed-fps','60','res://tests/fishing_b_runner.tscn']),
    ('livestock-b', ['--fixed-fps','60','res://tests/livestock_b_runner.tscn']),
    ('kitchen-b', ['--fixed-fps','60','res://tests/kitchen_b_runner.tscn']),
    ('ecology-b', ['--fixed-fps','60','res://tests/ecology_b_runner.tscn']),
    ('festivals-c', ['--fixed-fps','60','res://tests/festivals_c_runner.tscn']),
    ('social-c', ['--fixed-fps','60','res://tests/social_c_runner.tscn']),
    ('housing-c', ['--fixed-fps','60','res://tests/housing_c_runner.tscn']),
    ('exploration-d', ['--fixed-fps','60','res://tests/exploration_d_runner.tscn']),
    ('world-progress-d', ['--fixed-fps','60','res://tests/world_progress_d_runner.tscn']),
    ('quality-070', ['--fixed-fps','60','res://tests/quality_070_runner.tscn']),
    ('performance-070', ['--fixed-fps','60','res://tests/performance_070.tscn']),
    ('finale-070', ['--fixed-fps','60','res://tests/finale_070_runner.tscn']),
    ('palm-071', ['--fixed-fps','60','res://tests/palm_runner.tscn']),
    ('recovery-071', ['--fixed-fps','60','res://tests/recovery_071_runner.tscn']),
    ('tutorial-ui-071', ['--fixed-fps','60','res://tests/tutorial_071_runner.tscn']),
    ('performance-071', ['--fixed-fps','60','res://tests/performance_071.tscn']),
    ('touch-polish', ['--fixed-fps','60','res://tests/touch_polish_runner.tscn']),
    ('farming-actions', ['--fixed-fps','60','res://tests/farming_actions_runner.tscn']),
    ('food-recovery', ['--fixed-fps','60','res://tests/food_recovery_runner.tscn']),
    ('ui04-theme', ['res://tests/ui04_runner.tscn','--','--theme-only']),
    ('inventory03', ['--fixed-fps','60','res://tests/inventory03_runner.tscn']),
    ('hotbar03', ['--fixed-fps','60','res://tests/hotbar03_runner.tscn']),
    ('persist-write', ['res://tests/persistence.tscn','--','--write-save']),
    ('persist-restart', ['res://tests/persistence.tscn']),
    ('legacy-write', ['res://tests/persistence.tscn','--','--legacy-write']),
    ('legacy-restart', ['res://tests/persistence.tscn','--','--legacy-read']),
    ('mine-persist-write', ['res://tests/mining_persistence.tscn','--','--write-mine-save']),
    ('mine-persist-restart', ['res://tests/mining_persistence.tscn']),
    ('mine-backup-write', ['res://tests/mining_persistence.tscn','--','--write-mine-save']),
    ('mine-backup-corrupt', ['res://tests/mining_persistence.tscn','--','--corrupt-mine-save']),
    ('mine-backup-restart', ['res://tests/mining_persistence.tscn']),
    ('star-persist-write', ['res://tests/star_persistence.tscn','--','--write-star-save']),
    ('star-persist-restart', ['res://tests/star_persistence.tscn']),
    ('star-backup-corrupt', ['res://tests/star_persistence.tscn','--','--corrupt-star-save']),
    ('star-backup-restart', ['res://tests/star_persistence.tscn']),
    ('abyss-write', ['res://tests/abyss_persistence.tscn','--','--write-abyss']),
    ('abyss-restart', ['--fixed-fps','60','res://tests/abyss_persistence.tscn']),
    ('abyss-corrupt', ['res://tests/abyss_persistence.tscn','--','--corrupt-abyss']),
    ('abyss-backup', ['--fixed-fps','60','res://tests/abyss_persistence.tscn']),
    ('river-write', ['res://tests/river_persistence.tscn','--','--write-river']),
    ('river-restart', ['--fixed-fps','60','res://tests/river_persistence.tscn']),
    ('river-corrupt', ['res://tests/river_persistence.tscn','--','--corrupt-river']),
    ('river-backup', ['--fixed-fps','60','res://tests/river_persistence.tscn']),
    ('stability-write', ['res://tests/stability_persistence.tscn','--','--write-stability']),
    ('stability-restart', ['res://tests/stability_persistence.tscn']),
    ('stability-corrupt', ['res://tests/stability_persistence.tscn','--','--corrupt-stability']),
    ('stability-backup', ['res://tests/stability_persistence.tscn']),
    ('aquaculture-write', ['res://tests/aquaculture_persistence.tscn','--','--write-aquaculture']),
    ('aquaculture-restart', ['res://tests/aquaculture_persistence.tscn']),
    ('aquaculture-corrupt', ['res://tests/aquaculture_persistence.tscn','--','--corrupt-aquaculture']),
    ('aquaculture-backup', ['res://tests/aquaculture_persistence.tscn']),
    ('seasons-write', ['res://tests/seasons_a_persistence.tscn','--','--write-seasons']),
    ('seasons-restart', ['res://tests/seasons_a_persistence.tscn']),
    ('seasons-corrupt', ['res://tests/seasons_a_persistence.tscn','--','--corrupt-seasons']),
    ('seasons-backup', ['res://tests/seasons_a_persistence.tscn']),
    ('fishing-b-write', ['--fixed-fps', '60', 'res://tests/fishing_b_persistence.tscn', '--', '--write-fishing']),
    ('fishing-b-restart', ['--fixed-fps', '60', 'res://tests/fishing_b_persistence.tscn']),
    ('fishing-b-corrupt', ['--fixed-fps', '60', 'res://tests/fishing_b_persistence.tscn', '--', '--corrupt-fishing']),
    ('fishing-b-backup', ['--fixed-fps', '60', 'res://tests/fishing_b_persistence.tscn']),
    ('livestock-b-write', ['--fixed-fps', '60', 'res://tests/livestock_b_persistence.tscn', '--', '--write-livestock']),
    ('livestock-b-restart', ['--fixed-fps', '60', 'res://tests/livestock_b_persistence.tscn']),
    ('livestock-b-corrupt', ['--fixed-fps', '60', 'res://tests/livestock_b_persistence.tscn', '--', '--corrupt-livestock']),
    ('livestock-b-backup', ['--fixed-fps', '60', 'res://tests/livestock_b_persistence.tscn']),
    ('kitchen-b-write', ['--fixed-fps', '60', 'res://tests/kitchen_b_persistence.tscn', '--', '--write-kitchen']),
    ('kitchen-b-restart', ['--fixed-fps', '60', 'res://tests/kitchen_b_persistence.tscn']),
    ('kitchen-b-corrupt', ['--fixed-fps', '60', 'res://tests/kitchen_b_persistence.tscn', '--', '--corrupt-kitchen']),
    ('kitchen-b-backup', ['--fixed-fps', '60', 'res://tests/kitchen_b_persistence.tscn']),
    ('social-c-write', ['--fixed-fps', '60', 'res://tests/social_c_persistence.tscn', '--', '--write-social']),
    ('social-c-restart', ['--fixed-fps', '60', 'res://tests/social_c_persistence.tscn']),
    ('social-c-corrupt', ['--fixed-fps', '60', 'res://tests/social_c_persistence.tscn', '--', '--corrupt-social']),
    ('social-c-backup', ['--fixed-fps', '60', 'res://tests/social_c_persistence.tscn']),
    ('life-c-write', ['--fixed-fps', '60', 'res://tests/life_c_persistence.tscn', '--', '--write-life']),
    ('life-c-restart', ['--fixed-fps', '60', 'res://tests/life_c_persistence.tscn']),
    ('life-c-corrupt', ['--fixed-fps', '60', 'res://tests/life_c_persistence.tscn', '--', '--corrupt-life']),
    ('life-c-backup', ['--fixed-fps', '60', 'res://tests/life_c_persistence.tscn']),
    ('exploration-d-write', ['--fixed-fps', '60', 'res://tests/exploration_d_persistence.tscn', '--', '--write-exploration']),
    ('exploration-d-restart', ['--fixed-fps', '60', 'res://tests/exploration_d_persistence.tscn']),
    ('exploration-d-corrupt', ['--fixed-fps', '60', 'res://tests/exploration_d_persistence.tscn', '--', '--corrupt-exploration']),
    ('exploration-d-backup', ['--fixed-fps', '60', 'res://tests/exploration_d_persistence.tscn']),
    ('world-progress-d-write', ['--fixed-fps', '60', 'res://tests/world_progress_d_persistence.tscn', '--', '--write-world-progress']),
    ('world-progress-d-restart', ['--fixed-fps', '60', 'res://tests/world_progress_d_persistence.tscn']),
    ('world-progress-d-corrupt', ['--fixed-fps', '60', 'res://tests/world_progress_d_persistence.tscn', '--', '--corrupt-world-progress']),
    ('world-progress-d-backup', ['--fixed-fps', '60', 'res://tests/world_progress_d_persistence.tscn']),
    ('palm-write', ['--fixed-fps','60','res://tests/palm_persistence.tscn','--','--write-palm']),
    ('palm-restart', ['--fixed-fps','60','res://tests/palm_persistence.tscn']),
    ('palm-interrupt', ['res://tests/palm_persistence.tscn','--','--interrupt-palm']),
    ('palm-interrupted-restart', ['--fixed-fps','60','res://tests/palm_persistence.tscn']),
    ('palm-corrupt', ['res://tests/palm_persistence.tscn','--','--corrupt-palm']),
    ('palm-backup', ['--fixed-fps','60','res://tests/palm_persistence.tscn']),
    ('touch-polish-write', ['--fixed-fps','60','res://tests/touch_polish_persistence.tscn','--','--write-touch-polish']),
    ('touch-polish-restart', ['--fixed-fps','60','res://tests/touch_polish_persistence.tscn']),
    ('farm-windup-write', ['--fixed-fps','60','res://tests/farming_actions_persistence.tscn','--','--write-farm-windup']),
    ('farm-windup-read', ['--fixed-fps','60','res://tests/farming_actions_persistence.tscn','--','--read-farm-windup']),
    ('farm-impact-write', ['--fixed-fps','60','res://tests/farming_actions_persistence.tscn','--','--write-farm-impact']),
    ('farm-impact-read', ['--fixed-fps','60','res://tests/farming_actions_persistence.tscn','--','--read-farm-impact']),
    ('inventory03-write', ['--fixed-fps','60','res://tests/inventory03_persistence.tscn','--','--write-inventory03']),
    ('inventory03-read', ['--fixed-fps','60','res://tests/inventory03_persistence.tscn']),
    ('main-smoke', ['--quit-after','180']),
]
with tempfile.TemporaryDirectory(prefix='pixel-farm-test-') as profile:
    env = dict(os.environ, XDG_DATA_HOME=profile, APPDATA=profile)
    for name, options in steps:
        result = subprocess.run([godot,'--headless','--path',str(ROOT),*options],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',timeout=600 if name in ['river','stability'] else 180)
        (logs/(name+'.log')).write_text(result.stdout, encoding='utf-8')
        print(result.stdout, end='')
        if result.returncode or any(marker in result.stdout for marker in ['SCRIPT ERROR:','ERROR:','FAIL:','instances leaked']):
            raise SystemExit(f'{name} failed; see builds/{name}.log')
        print(f'[{name}] PASS')
print('ALL CHECKS PASSED: ' + version)
