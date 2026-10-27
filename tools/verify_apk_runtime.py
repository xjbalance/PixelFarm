"""提取最终 APK 的实际 assets，在隔离目录用桌面 Godot 启动；这不替代 Android 真机测试。"""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
version = re.search(r'^config/version="([^"]+)"', (root/'project.godot').read_text(),re.MULTILINE).group(1)
apk_path = root/f'builds/PixelWorld-{version}-debug.apk'
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
    # 除原存档/物品接口外，最终包必须确实包含本轮相机与紧凑工具栏接口。
    (workspace/'artifact_probe.gd').write_text('extends Node\nfunc _ready() -> void:\n\tGameClock.running=false\n\tvar save_script: GDScript=load("res://scripts/save/save_store.gd")\n\tvar audio_script: GDScript=load("res://scripts/core/audio.gd")\n\tvar farm_script: GDScript=load("res://scripts/farming/farm.gd")\n\tvar ok: bool=int(save_script.get_script_constant_map().get("VERSION",0))==24 and Housing.defaults().has("flowers") and Housing.defaults().has("construction") and Housing.defaults().has("builtins")\n\tok=ok and load("res://scripts/tutorial/game_tutorial.gd").help_text().length()>100\n\tok=ok and not audio_script.get_script_constant_map().has("SOUNDS") and not farm_script.get_script_constant_map().has("CROP_TEXTURE")\n\tvar inventory_script: GDScript=load("res://scripts/ui/inventory_panel.gd")\n\tvar sale_api: bool=false\n\tfor entry in inventory_script.get_script_method_list():\n\t\tif entry.name=="confirm_sale": sale_api=true\n\tok=ok and sale_api\n\tvar hud_script: GDScript=load("res://scripts/ui/hud.gd")\n\tvar compact_api: bool=false\n\tfor entry in hud_script.get_script_method_list():\n\t\tif entry.name=="expand_hotbar": compact_api=true\n\tok=ok and compact_api and ResourceLoader.exists("res://scripts/presentation/camera_rig.gd")\n\tok=ok and load("res://scripts/presentation/camera_rig.gd").get_script_constant_map().Mode.has("FREE_LOOK")\n\tok=ok and ResourceLoader.exists("res://scripts/housing/home_rest_controller.gd") and ResourceLoader.exists("res://assets/housing/interior/sofa_estate.png")\n\tok=ok and ResourceLoader.exists("res://scripts/gathering/resource_world.gd") and load("res://scripts/gathering/resource_catalog.gd").all_placements().size()==128\n\tok=ok and ResourceLoader.exists("res://scripts/housing/home_arrange_controller.gd") and Housing.defaults().builtins.size()>=16\n\tvar ui_theme: Theme=load("res://scripts/ui/ui_style.gd").make_theme()\n\tok=ok and ui_theme.get_stylebox("panel","PanelContainer") is StyleBoxTexture\n\tok=ok and ResourceLoader.exists("res://assets/ui/river/icon_task.png")\n\tok=ok and load("res://scripts/ui/ui_metrics.gd").logical_touch_size(480,Vector2(2400,1080),Vector2(1600,720))==96\n\tGameClock.day=15;GameClock.minutes=1200;Calendar.restore(Calendar.snapshot());GameWeather.enabled=true\n\tok=ok and GameWeather.is_moon_night() and Catalog.is_item("spring_bloom_seed") and Catalog.is_item("moon_note")\n\tprint("APK CODE INVARIANTS: ","PASS" if ok else "FAIL")\n\tget_tree().quit(0 if ok else 1)\n',encoding='utf-8')
    (workspace/'artifact_probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://artifact_probe.gd" id="1"]\n[node name="ArtifactProbe" type="Node"]\nscript = ExtResource("1")\n')
    probe = subprocess.run([str(engine),'--headless','--path',str(workspace),'res://artifact_probe.tscn'],env=dict(os.environ,XDG_DATA_HOME=str(profile)),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
    print(probe.stdout)
    with log.open('a') as stream: stream.write(probe.stdout)
    if probe.returncode or 'APK CODE INVARIANTS: PASS' not in probe.stdout or any(marker in probe.stdout for marker in ['SCRIPT ERROR:','ERROR:','instances leaked']):
        raise SystemExit('实际APK代码/数据版本不一致')
