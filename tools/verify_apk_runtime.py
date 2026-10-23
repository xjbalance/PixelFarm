"""提取最终 APK 的实际 assets，在隔离目录用桌面 Godot 启动；这不替代 Android 真机测试。"""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
version = re.search(r'^config/version="([^"]+)"', (root/'project.godot').read_text(),re.MULTILINE).group(1)
apk_path = root/f'builds/PixelFarm-{version}-debug.apk'
engine = root/'.tools/Godot_v4.3-stable_linux.x86_64'
with tempfile.TemporaryDirectory(prefix='pixelfarm-apk-') as directory:
    workspace = Path(directory)/'game'
    profile = Path(directory)/'profile'
    workspace.mkdir()
    count = 0
    with zipfile.ZipFile(apk_path) as apk:
        for name in apk.namelist():
            if not name.startswith('assets/') or name.endswith('/'): continue
            relative = Path(name).relative_to('assets')
            if '..' in relative.parts: raise RuntimeError('APK 路径越界')
            path = workspace/relative
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(apk.read(name))
            count += 1
    result = subprocess.run([str(engine),'--headless','--path',str(workspace),'--quit-after','180'],
                            env=dict(os.environ,XDG_DATA_HOME=str(profile)),stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT,text=True,timeout=90)
    output = f'Final APK: {apk_path.name}\nExtracted assets: {count}\n'+result.stdout
    log = root/f'builds/android-apk-assets-runtime-{version}.log'
    log.write_text(output)
    print(output)
    if result.returncode or any(marker in output for marker in ['SCRIPT ERROR:','ERROR:','instances leaked']):
        raise SystemExit('APK 资源独立启动失败')
    print('PASS: 最终 APK 的实际资源脱离源码启动 180 帧，无脚本、资源或运行时错误。')
