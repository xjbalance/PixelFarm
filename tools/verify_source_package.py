"""在全新目录检查实际源码包：CRC/数据/无密钥、空缓存完整导入及主场景启动。"""
from pathlib import Path
import os,re,subprocess,tempfile,zipfile
ROOT=Path(__file__).resolve().parents[1]
version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(),re.M).group(1)
archive=ROOT/f'builds/PixelWorld-{version}-source.zip';engine=ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'
with tempfile.TemporaryDirectory(prefix='pixelworld-source-test-') as directory:
 root=Path(directory)
 with zipfile.ZipFile(archive) as package:
  assert package.testzip() is None
  names=package.namelist()
  for name in names:
   assert '..' not in Path(name).parts
   assert not any(part in ['.git','.tools','.godot','need'] for part in Path(name).parts)
   assert not name.endswith(('.keystore','.jks','.key','.p12','.pfx','.pem'))
   assert Path(name).name!='export_credentials.cfg'
   assert not Path(name).name.startswith('.env') or Path(name).name=='.env.example'
  assert package.read('PixelWorld/project.godot')==(ROOT/'project.godot').read_bytes()
  for source in (ROOT/'resources').rglob('*.json'):
   assert package.read('PixelWorld/'+source.relative_to(ROOT).as_posix())==source.read_bytes(),source
  for folder,pattern in [('scripts','*.gd'),('assets','*.png')]:
   for source in (ROOT/folder).rglob(pattern):
    assert package.read('PixelWorld/'+source.relative_to(ROOT).as_posix())==source.read_bytes(),source
  package.extractall(root/'game')
 project=root/'game/PixelWorld';env=dict(os.environ,XDG_DATA_HOME=str(root/'profile'),APPDATA=str(root/'profile'))
 with (ROOT/f'builds/source-runtime-{version}-final.log').open('w') as log:
  log.write(f'Archive: {archive.name}\nFiles: {len(names)}\nCRC / all JSON data / all game scripts / PNG assets / version / excluded secrets and need: PASS\n');log.flush()
  for label,args in [('fresh-import',['--import']),('fresh-main',['--quit-after','180'])]:
   result=subprocess.run([str(engine),'--headless','--path',str(project),*args],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
   log.write(result.stdout);log.flush()
   if result.returncode or any(marker in result.stdout for marker in ['ERROR:','SCRIPT ERROR:','instances leaked']): raise SystemExit(label+' failed; see source-runtime log')
   log.write(label+': PASS\n');log.flush()
  log.write('SOURCE ARCHIVE ACCEPTANCE: PASS\n')
 print('SOURCE ARCHIVE ACCEPTANCE: PASS')
