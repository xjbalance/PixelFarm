"""只检查，不安装软件，不改全局配置，不自动连接或部署到设备。"""
from pathlib import Path
import os
import shutil
import subprocess

missing = []
jdk = os.environ.get('JAVA_HOME')
java_name = 'java.exe' if os.name == 'nt' else 'java'
java = shutil.which('java') or (str(Path(jdk)/'bin'/java_name) if jdk else None)
if java and Path(java).exists():
    result = subprocess.run([java,'-version'],capture_output=True,text=True)
    print(result.stderr.strip())
else:
    missing.append('JDK 17（java / JAVA_HOME）')
sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
default_sdk = Path(os.environ.get('LOCALAPPDATA',str(Path.home()/'AppData/Local')))/'Android/Sdk' if os.name == 'nt' else Path.home()/'Android/Sdk'
sdk_path = Path(sdk) if sdk else default_sdk
for name in ['platform-tools','build-tools/34.0.0','platforms/android-34','cmdline-tools']:
    found = (sdk_path/name).exists()
    print(('OK ' if found else 'MISSING ') + str(sdk_path/name))
    if not found: missing.append('Android SDK ' + name)
if os.name == 'nt':
    templates = Path(os.environ.get('APPDATA',''))/'Godot/export_templates/4.3.stable'
else:
    templates = Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'godot/export_templates/4.3.stable'
if not (templates/'android_debug.apk').exists():
    missing.append('Godot 4.3 官方导出模板 android_debug.apk')
print('模板目录:',templates)
if missing:
    print('未满足 APK 构建条件：\n- '+'\n- '.join(missing))
    raise SystemExit(1)
print('基础依赖存在。请在 Godot 编辑器中配置 SDK 路径与调试签名，然后运行导出命令。')
