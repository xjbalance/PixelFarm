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
    ('integration', ['res://tests/runner.tscn']),
    ('persist-write', ['res://tests/persistence.tscn','--','--write-save']),
    ('persist-restart', ['res://tests/persistence.tscn']),
    ('legacy-write', ['res://tests/persistence.tscn','--','--legacy-write']),
    ('legacy-restart', ['res://tests/persistence.tscn','--','--legacy-read']),
    ('main-smoke', ['--quit-after','180']),
]
with tempfile.TemporaryDirectory(prefix='pixel-farm-test-') as profile:
    env = dict(os.environ, XDG_DATA_HOME=profile, APPDATA=profile)
    for name, options in steps:
        result = subprocess.run([godot,'--headless','--path',str(ROOT),*options],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',timeout=120)
        (logs/(name+'.log')).write_text(result.stdout, encoding='utf-8')
        print(result.stdout, end='')
        if result.returncode or any(marker in result.stdout for marker in ['SCRIPT ERROR:','ERROR:','FAIL:','instances leaked']):
            raise SystemExit(f'{name} failed; see builds/{name}.log')
        print(f'[{name}] PASS')
print('ALL CHECKS PASSED: ' + version)
