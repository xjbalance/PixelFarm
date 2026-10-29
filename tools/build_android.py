"""使用项目内便携工具导出并验证 APK；不安装软件、不修改全局配置。

当前脚本用于 Linux 构建机。Windows 手动导出方法见 docs/ANDROID.md。
依赖放在 .tools/android/；必须复用原更新签名，密钥缺失时不自动新建。
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / '.tools/android'
VERSION = re.search(r'^config/version="([^"]+)"',
                    (ROOT / 'project.godot').read_text(), re.MULTILINE).group(1)


def run(label, command, env, log_name):
    print(label, flush=True)
    result = subprocess.run([str(arg) for arg in command], cwd=ROOT, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors='replace')
    log = ROOT / 'builds' / log_name
    log.write_text(result.stdout, encoding='utf-8')
    if result.returncode != 0:
        print(result.stdout[-12000:], file=sys.stderr)
        raise RuntimeError(f'{label}失败，退出码 {result.returncode}；日志：{log}')
    return result.stdout


def build():
    if not sys.platform.startswith('linux'):
        raise RuntimeError('此入口使用 Linux 便携工具；Windows 请按 docs/ANDROID.md 导出。')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path,
                        default=ROOT / f'builds/PixelWorld-{VERSION}-debug.apk')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.suffix.lower() != '.apk':
        parser.error('--output 必须以 .apk 结尾')
    output.parent.mkdir(parents=True, exist_ok=True)
    (ROOT / 'builds').mkdir(exist_ok=True)
    engine = ROOT / '.tools/Godot_v4.3-stable_linux.x86_64'
    jdk, sdk = LOCAL / 'jdk', LOCAL / 'sdk'
    profile = LOCAL / 'profile'
    keystore = LOCAL / 'keys/pixelfarm-debug.keystore'
    env = os.environ.copy()
    env.update({
        'JAVA_HOME': str(jdk), 'ANDROID_HOME': str(sdk),
        'ANDROID_SDK_ROOT': str(sdk),
        'ANDROID_USER_HOME': str(profile / 'android'),
        'XDG_CONFIG_HOME': str(profile / 'config'),
        'XDG_DATA_HOME': str(profile / 'data'),
        'XDG_CACHE_HOME': str(profile / 'cache'),
        'PATH': str(jdk / 'bin') + os.pathsep + env.get('PATH', ''),
    })
    # 编辑器会探测 adb；使用独立端口，避免重启其他项目正在使用的服务器。
    env.setdefault('ADB_SERVER_SOCKET', 'tcp:localhost:15037')
    for name in ['config/godot', 'data', 'cache', 'android']:
        (profile / name).mkdir(parents=True, exist_ok=True)
    run('检查 JDK、SDK 和模板', [sys.executable, ROOT / 'tools/android_preflight.py'],
        env, f'android-preflight-{VERSION}.log')
    if not engine.is_file():
        raise RuntimeError(f'缺少 Godot 4.3 便携引擎：{engine}')
    if not keystore.exists():
        raise RuntimeError('缺少原有更新签名。为避免破坏覆盖安装，本脚本不会创建新密钥。请恢复原 keystore。')

    # 只写入项目隔离的编辑器配置，保留用户原有 Godot/JDK/SDK 设置。
    settings = {
        'export/android/java_sdk_path': str(jdk),
        'export/android/android_sdk_path': str(sdk),
        'export/android/debug_keystore': str(keystore),
        'export/android/debug_keystore_user': 'androiddebugkey',
        'export/android/debug_keystore_pass': 'android',
        'export/android/shutdown_adb_on_exit': False,
    }
    config = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    config += ''.join(f'{key} = {json.dumps(value)}\n' for key, value in settings.items())
    (profile / 'config/godot/editor_settings-4.3.tres').write_text(config, encoding='utf-8')
    # 导出到临时文件，完整验证后才替换交付 APK，避免误把旧文件当作成功结果。
    pending = output.with_name(output.stem + '.pending.apk')
    if pending.exists():
        pending.unlink()
    export_log = run('Godot 4.3 导出 Android Debug', [
        engine, '--headless', '--path', ROOT,
        '--export-debug', 'Android Debug', pending,
    ], env, f'android-export-{VERSION}.log')
    if re.search(r'(?:SCRIPT ERROR:|^ERROR:|Export failed)', export_log, re.MULTILINE):
        raise RuntimeError('导出日志存在错误，请查看 builds/android-export-' + VERSION + '.log')
    if not pending.is_file() or pending.stat().st_size == 0:
        raise RuntimeError('Godot 未生成非空 APK')

    build_tools = sdk / 'build-tools/34.0.0'
    signatures = run('验证 APK 签名', [
        build_tools / 'apksigner', 'verify', '--verbose', '--print-certs', pending,
    ], env, f'android-signature-{VERSION}.log')
    expected_cert = '89455063278c15e708389a2caff957c7254ff2e88b3e19aaf23cdd755c90414b'
    if f'certificate SHA-256 digest: {expected_cert}' not in signatures:
        raise RuntimeError('签名证书与0.3.0不一致，拒绝交付覆盖更新包')
    run('验证 ZIP 对齐', [build_tools / 'zipalign', '-c', '-v', '4', pending],
        env, f'android-alignment-{VERSION}.log')
    badging = run('检查包名、版本、启动入口和设备要求', [
        build_tools / 'aapt', 'dump', 'badging', pending,
    ], env, f'android-manifest-{VERSION}.log')
    manifest = run('读取完整 Android 清单', [
        build_tools / 'aapt', 'dump', 'xmltree', pending, 'AndroidManifest.xml',
    ], env, f'android-manifest-tree-{VERSION}.log')
    version_code = re.search(r'^version/code=(\d+)', (ROOT / 'export_presets.cfg').read_text(), re.MULTILINE).group(1)
    required = ["package: name='org.pixelfarm.windbud'", f"versionName='{VERSION}'", f"versionCode='{version_code}'",
                "launchable-activity: name='com.godot.game.GodotApp'"]
    if not all(value in badging for value in required):
        raise RuntimeError('包名、版本或启动入口与工程配置不一致')
    if 'android:screenOrientation' not in manifest:
        raise RuntimeError('缺少横屏配置')
    with zipfile.ZipFile(pending) as apk:
        damaged = apk.testzip()
        if damaged:
            raise RuntimeError(f'APK 内文件 CRC 校验失败：{damaged}')
        names = set(apk.namelist())
        for abi in ['arm64-v8a', 'armeabi-v7a']:
            if f'lib/{abi}/libgodot_android.so' not in names:
                raise RuntimeError(f'APK 缺少 {abi} 引擎')
        for resource in (ROOT / 'resources').rglob('*.json'):
            name = 'assets/' + resource.relative_to(ROOT).as_posix()
            if name not in names or apk.read(name) != resource.read_bytes():
                raise RuntimeError(f'APK 缺少或改变了游戏数据：{name}')
        for resource in [*(ROOT/'assets/credits').glob('*.txt'), ROOT/'assets/ui/fonts/LICENSE.txt']:
            name = 'assets/' + resource.relative_to(ROOT).as_posix()
            if name not in names or apk.read(name) != resource.read_bytes():
                raise RuntimeError(f'APK 缺少引擎或字体许可：{name}')
    checksum = hashlib.sha256(pending.read_bytes()).hexdigest()
    pending.replace(output)
    output.with_suffix('.apk.sha256').write_text(
        checksum + '  ' + output.name + '\n', encoding='ascii')
    # apksigner 的 v4 旁车文件不是手机安装所需，不交付临时文件名的副本。
    idsig = pending.with_suffix('.apk.idsig')
    if idsig.exists():
        idsig.unlink()
    print(signatures)
    for line in badging.splitlines():
        if line.startswith(('package:', 'sdkVersion:', 'targetSdkVersion:',
                            'application:', 'launchable-activity:', 'native-code:')):
            print(line)
    print(f'APK: {output}\n大小: {output.stat().st_size} 字节\nSHA256: {checksum}')


if __name__ == '__main__':
    try:
        build()
    except (RuntimeError, OSError, zipfile.BadZipFile) as error:
        print(f'构建失败：{error}', file=sys.stderr)
        raise SystemExit(1)
