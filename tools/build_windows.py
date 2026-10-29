"""Linux 便携工具导出 Windows64 成品 ZIP；不改游戏逻辑、全局环境或真实玩家存档。"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.search(r'^config/version="([^"]+)"', (ROOT / 'project.godot').read_text(), re.M).group(1)
ENGINE = ROOT / '.tools/Godot_v4.3-stable_linux.x86_64'
LOCAL = ROOT / '.tools/windows'
PROFILE = LOCAL / 'profile'
DEST = ROOT / f'builds/PixelWorld-{VERSION}-Windows-x64'
ARCHIVE = DEST.parent / (DEST.name + '.zip')


def run(label, command, env, log_name, cwd=ROOT):
    print(label, flush=True)
    result = subprocess.run([str(arg) for arg in command], cwd=cwd, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors='replace', timeout=240)
    (ROOT / 'builds' / log_name).write_text(result.stdout)
    if result.returncode or any(marker in result.stdout for marker in ['ERROR:', 'SCRIPT ERROR:', 'instances leaked', 'Fatal error', 'Could not start rcedit']):
        raise RuntimeError(label + '失败；请检查 builds/' + log_name)
    return result.stdout


def validate_exe(path):
    with path.open('rb') as stream:
        assert stream.read(2) == b'MZ', '缺少 Windows EXE 头'
        stream.seek(60)
        pe_offset = struct.unpack('<I', stream.read(4))[0]
        stream.seek(pe_offset)
        assert stream.read(4) == b'PE\0\0'
        assert struct.unpack('<H', stream.read(2))[0] == 0x8664, '不是 Windows64'


def validate_pack(path):
    with path.open('rb') as stream:
        magic, fmt, major, minor, _ = struct.unpack('<4s4I', stream.read(20))
        assert magic == b'GDPC' and fmt == 2 and (major, minor) == (4, 3), '缺少匹配的独立游戏资源包'
    return path.stat().st_size


def file_version(path):
    """读取 PE 的 RT_VERSION / VS_FIXEDFILEINFO，避免混同可选的版本字符串。"""
    with path.open('rb') as stream:
        stream.seek(60)
        pe = struct.unpack('<I', stream.read(4))[0]
        stream.seek(pe + 6)
        section_count = struct.unpack('<H', stream.read(2))[0]
        stream.seek(pe + 20)
        optional_size = struct.unpack('<H', stream.read(2))[0]
        optional = pe + 24
        stream.seek(optional)
        assert struct.unpack('<H', stream.read(2))[0] == 0x20B
        stream.seek(optional + 112 + 16)
        resource_rva, resource_size = struct.unpack('<II', stream.read(8))
        assert resource_size > 0
        stream.seek(optional + optional_size)
        sections = []
        for _ in range(section_count):
            header = stream.read(40)
            virtual_size, address, raw_size, offset = struct.unpack_from('<4I', header, 8)
            sections.append((address, max(virtual_size, raw_size), offset))

        def raw_offset(rva):
            for address, size, offset in sections:
                if address <= rva < address + size:
                    return offset + rva - address
            raise ValueError('PE资源地址无效')

        base = raw_offset(resource_rva)

        def entries(offset):
            stream.seek(base + offset + 12)
            named, ids = struct.unpack('<HH', stream.read(4))
            return [struct.unpack('<II', stream.read(8)) for _ in range(named + ids)]

        value = next(value for name, value in entries(0) if name == 16)
        while value & 0x80000000:
            value = entries(value & 0x7FFFFFFF)[0][1]
        stream.seek(base + value)
        rva, size, _, _ = struct.unpack('<4I', stream.read(16))
        stream.seek(raw_offset(rva))
        data = stream.read(size)
        key = 'VS_VERSION_INFO\0'.encode('utf-16le')
        assert data[6:6 + len(key)] == key
        offset = (6 + len(key) + 3) & ~3
        fixed = struct.unpack_from('<13I', data, offset)
        assert fixed[0] == 0xFEEF04BD
        ms, ls = fixed[2:4]
        return f'{ms >> 16}.{ms & 65535}.{ls >> 16}.{ls & 65535}'


def build():
    template = PROFILE / 'data/godot/export_templates/4.3.stable/windows_release_x86_64.exe'
    wine = LOCAL / 'runtime/bin/wine-portable'
    rcedit = LOCAL / 'bin/rcedit-x64.exe'
    for path in [ENGINE, template, wine, rcedit]:
        if not path.is_file():
            raise RuntimeError('缺少便携构建工具：' + str(path))
    assert subprocess.check_output([str(ENGINE), '--version'], text=True).startswith('4.3.')
    env = dict(os.environ, XDG_DATA_HOME=str(PROFILE / 'data'),
               XDG_CONFIG_HOME=str(PROFILE / 'config'), XDG_CACHE_HOME=str(PROFILE / 'cache'),
               APPDATA=str(PROFILE / 'data'), WINEDEBUG='-all')
    settings = PROFILE / 'config/godot/editor_settings-4.3.tres'
    settings.parent.mkdir(parents=True, exist_ok=True)
    (PROFILE / 'cache').mkdir(parents=True, exist_ok=True)
    settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                        + 'export/windows/wine = ' + json.dumps(str(wine)) + '\n'
                        + 'export/windows/rcedit = ' + json.dumps(str(rcedit)) + '\n')
    with tempfile.TemporaryDirectory(prefix='windows-pending-', dir=ROOT / 'builds') as folder:
        pending = Path(folder) / 'PixelWorld.exe'
        run('导出 Windows64 Release', [ENGINE, '--headless', '--path', ROOT,
                                      '--export-release', 'Windows Desktop', pending],
            env, f'windows-export-{VERSION}.log')
        validate_exe(pending)
        pack = pending.with_suffix('.pck')
        pack_size = validate_pack(pack)
        metadata = run('验证 EXE 产品信息', [wine, rcedit, pending, '--get-version-string', 'ProductName'],
                       env, f'windows-version-{VERSION}.log')
        assert 'Pixel World' in metadata and file_version(pending) == VERSION + '.0', 'EXE 产品或固定版本资源不正确'
        with tempfile.TemporaryDirectory(prefix='pixelworld-windows-pack-') as data:
            runtime_env = dict(os.environ, XDG_DATA_HOME=data, APPDATA=data)
            run('从实际 Windows PCK 资源启动检查', [ENGINE, '--headless', '--main-pack', pack,
                                          '--audio-driver', 'Dummy', '--quit-after', '180'],
                runtime_env, f'windows-packed-runtime-{VERSION}.log', cwd=data)
        DEST.mkdir(parents=True, exist_ok=True)
        exe = DEST / 'PixelWorld.exe'
        shutil.copyfile(pending, exe)
        shutil.copyfile(pack, DEST / 'PixelWorld.pck')
        readme = f'''像素世界 {VERSION}《丰收匠心》· Windows 64位版

1. 将整个 ZIP 解压到普通文件夹。
2. 双击 PixelWorld.exe 开始游戏，无需安装 Godot、Python 或 .NET。

推荐 Windows 10/11 64位，显卡驱动需要支持 OpenGL 3.3。
点击地面移动；WASD/方向键也可行走。E交互，B背包，J委托，M地图，Esc菜单，F5保存，F9读取。
开局选择人物；游玩中菜单可切换形象。建造入口：菜单→建造 / 改造领地。

存档自动保存在当前 Windows 用户的应用数据目录：
%APPDATA%\\Godot\\app_userdata\\Pixel Farm · 风芽农场\\farm_save.json
给其他玩家分享本 ZIP 即可；存档不在程序文件夹中。

PixelWorld.pck 是配套游戏资源，必须和 EXE 放在同一文件夹。分享时请发送完整 ZIP。
'''
        (DEST / '开始游戏.txt').write_text(readme, encoding='utf-8-sig')
        shutil.copyfile(ROOT / 'assets/ui/fonts/LICENSE.txt', DEST / '字体许可.txt')
        licenses = DEST / 'licenses'
        licenses.mkdir(exist_ok=True)
        credit_names = []
        for source in sorted((ROOT / 'assets/credits').glob('*.txt')):
            shutil.copyfile(source, licenses / source.name)
            credit_names.append('licenses/' + source.name)
        pending_zip = ARCHIVE.with_suffix('.pending.zip')
        package_names = ['PixelWorld.exe', 'PixelWorld.pck', '开始游戏.txt', '字体许可.txt', *credit_names]
        with zipfile.ZipFile(pending_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as package:
            for name in package_names:
                package.write(DEST / name, Path(DEST.name) / name)
        with zipfile.ZipFile(pending_zip) as package:
            assert package.testzip() is None
            assert len(package.namelist()) == len(package_names)
        pending_zip.replace(ARCHIVE)
        checksum = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
        ARCHIVE.with_suffix('.zip.sha256').write_text(checksum + '  ' + ARCHIVE.name + '\n')
        report = {'version': VERSION, 'platform': 'Windows x86_64', 'configuration': 'release',
                  'pck_bytes': pack_size, 'embedded_pck': False, 'exe_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
                  'pck_sha256': hashlib.sha256((DEST / 'PixelWorld.pck').read_bytes()).hexdigest(),
                  'files': package_names,
                  'zip': ARCHIVE.name, 'zip_bytes': ARCHIVE.stat().st_size, 'zip_sha256': checksum,
                  'zip_crc_verified': True, 'pe_amd64_verified': True, 'version_resource_verified': True,
                  'packed_resources_desktop_startup': True, 'windows_native_tested': False}
        (ROOT / f'builds/windows-package-{VERSION}.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(str(ARCHIVE) + '\nSHA256 ' + checksum)


if __name__ == '__main__':
    build()
