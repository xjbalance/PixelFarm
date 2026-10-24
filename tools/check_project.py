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
    ('import', ['--editor','--quit']),
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
    ('main-smoke', ['--quit-after','180']),
]
with tempfile.TemporaryDirectory(prefix='pixel-farm-test-') as profile:
    env = dict(os.environ, XDG_DATA_HOME=profile, APPDATA=profile)
    for name, options in steps:
        result = subprocess.run([godot,'--headless','--path',str(ROOT),*options],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',timeout=600 if name in ['river','stability'] else 120)
        (logs/(name+'.log')).write_text(result.stdout, encoding='utf-8')
        print(result.stdout, end='')
        if result.returncode or any(marker in result.stdout for marker in ['SCRIPT ERROR:','ERROR:','FAIL:','instances leaked']):
            raise SystemExit(f'{name} failed; see builds/{name}.log')
        print(f'[{name}] PASS')
print('ALL CHECKS PASSED: ' + version)
