"""Actual Godot windows, isolated profiles; captures never touch player saves."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
ENGINE=ROOT/'.tools/Godot_v4.3-stable_linux.x86_64'
OUT=ROOT/'docs/farm-diy'
WRAPPER='''extends "res://tests/farm_diy_editor_runner.gd"
func capture(label: String) -> void:
 await super.capture(label)
 if label!="home_after" or not capture_mode: return
 var window_size: Vector2i=get_window().size
 var zoom: Vector2=game.camera_rig.camera.zoom
 var mode: int=game.camera_rig.mode
 var center: Vector2=game.camera_rig.view_center
 var root_visible: bool=game.hud.root.visible
 var preview_visible: bool=editor.preview.visible
 game.hud.root.hide();editor.preview.hide()
 get_window().size=Vector2i(1536,1024);await frames(4)
 game.camera_rig.camera.zoom=Vector2.ONE
 game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK
 game.camera_rig.view_center=Vector2(768,512);game.camera_rig.apply_camera()
 await frames(5);await RenderingServer.frame_post_draw
 var path: String="res://builds/farm-diy-editor-full_farm_after.png"
 get_viewport().get_texture().get_image().save_png(path)
 captures.append({"name":"full_farm_after","path":path,"window":[1536,1024]})
 get_window().size=window_size;await frames(4)
 game.camera_rig.camera.zoom=zoom;game.camera_rig.mode=mode;game.camera_rig.view_center=center;game.camera_rig.apply_camera()
 game.hud.root.visible=root_visible;editor.preview.visible=preview_visible;await frames(5)
'''


def capture():
    (ROOT/'builds/farm_diy_window_capture.gd').write_text(WRAPPER)
    (ROOT/'builds/farm_diy_window_capture.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://builds/farm_diy_window_capture.gd" id="1"]\n[node name="FarmDIYCapture" type="Node"]\nscript = ExtResource("1")\n')
    display=next(f':{n}' for n in range(285,310) if not Path(f'/tmp/.X11-unix/X{n}').exists() and not Path(f'/tmp/.X{n}-lock').exists())
    server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,'-screen','0','1800x1100x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    results=[]
    try:
        time.sleep(.4)
        with tempfile.TemporaryDirectory(prefix='farm-diy-capture-') as profile:
            env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
            for name,scene in [('editor','res://builds/farm_diy_window_capture.tscn'),('production','res://tests/farm_diy_production_runner.tscn'),('business','res://tests/farm_layout_business_runner.tscn')]:
                result=subprocess.run([str(ENGINE),'--path',str(ROOT),'--audio-driver','Dummy','--fixed-fps','60','--max-fps','0',scene,'--','--capture'],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
                (ROOT/f'builds/farm-diy-final-window-{name}.log').write_text(result.stdout)
                lines=[x for x in result.stdout.splitlines() if 'RESULT' in x or 'ERROR:' in x]
                print(name,result.returncode,*lines,sep='\n',flush=True)
                if result.returncode or any(s in result.stdout for s in ['ERROR:','SCRIPT ERROR:','instances leaked']): raise RuntimeError('Window validation failed: '+name)
                results.append({'name':name,'exit':result.returncode,'results':lines})
    finally:
        server.terminate();server.wait(timeout=10)
    OUT.mkdir(exist_ok=True)
    for folder,pattern in [('editor','farm-diy-editor-*.png'),('production','farm-diy-production-*.png')]:
        target=OUT/folder;target.mkdir(exist_ok=True)
        for source in (ROOT/'builds').glob(pattern):shutil.copy2(source,target/source.name)
    for source in (ROOT/'builds').glob('farm-layout-business-*.png'):shutil.copy2(source,OUT/source.name)
    (ROOT/'builds/farm-diy-final-windows.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':capture()
