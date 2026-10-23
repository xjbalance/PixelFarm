"""打包可直接导入的完整源码，不含引擎、缓存、签名和本地构建产物。"""
from pathlib import Path
import hashlib
import zipfile
import re

ROOT = Path(__file__).resolve().parents[1]
version = re.search(r'^config/version="([^"]+)"', (ROOT/'project.godot').read_text(),re.MULTILINE).group(1)
out = ROOT/f'builds/PixelFarm-{version}-source.zip'
out.parent.mkdir(exist_ok=True)
excluded = {'.git','.tools','.godot','builds','__pycache__'}
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
    package.writestr('PixelFarm/builds/.gitkeep','')
    for path in sorted(ROOT.rglob('*')):
        relative = path.relative_to(ROOT)
        if not path.is_file() or any(part in excluded for part in relative.parts): continue
        if path.suffix in {'.pyc','.tmp','.keystore'}: continue
        package.write(path,Path('PixelFarm')/relative)
checksum = hashlib.sha256(out.read_bytes()).hexdigest()
out.with_suffix('.sha256').write_text(checksum+'  '+out.name+'\n',encoding='ascii')
print(f'{out}\n{out.stat().st_size} bytes\nSHA256 {checksum}')
