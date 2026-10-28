"""Actual Godot windows, isolated profiles; captures never touch player saves."""
from pathlib import Path
import argparse
import io
import json
import os
import shutil
import subprocess
import tempfile
import tarfile
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
 var visible: Vector2=get_viewport().get_visible_rect().size
 var fit: float=minf(visible.x/1536.0,visible.y/1024.0)
 game.camera_rig.camera.zoom=Vector2(fit,fit)
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
BEFORE='''extends Node
var game: Node
func _ready() -> void: call_deferred("run")
func frames(n: int) -> void:
 for i in range(n): await get_tree().physics_frame
func run() -> void:
 get_window().size=Vector2i(1536,1024)
 game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
 GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(10)
 game.tutorial.restore(GameTutorial.defaults(true));GameClock.minutes=720;GameClock.changed.emit()
 game.change_location("farm",Vector2(720,592));game.hud.root.hide();await frames(5)
 var visible: Vector2=get_viewport().get_visible_rect().size
 var fit: float=minf(visible.x/1536.0,visible.y/1024.0)
 game.camera_rig.camera.zoom=Vector2(fit,fit);game.camera_rig.mode=WorldCameraRig.Mode.FREE_LOOK
 game.camera_rig.view_center=Vector2(768,512);game.camera_rig.apply_camera()
 await get_tree().create_timer(2.9).timeout;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("%OUTPUT%")
 print("FARM DIY BEFORE CAPTURE: actual ea3204b window")
 game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit()
'''


def capture(before=False,editor_only=False,production_only=False):
    if not before and not production_only:
        (ROOT/'builds/farm_diy_window_capture.gd').write_text(WRAPPER)
        (ROOT/'builds/farm_diy_window_capture.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://builds/farm_diy_window_capture.gd" id="1"]\n[node name="FarmDIYCapture" type="Node"]\nscript = ExtResource("1")\n')
    display=next(f':{n}' for n in range(285,310) if not Path(f'/tmp/.X11-unix/X{n}').exists() and not Path(f'/tmp/.X{n}-lock').exists())
    server=subprocess.Popen([str(ROOT/'.tools/display/usr/bin/Xvfb'),display,'-screen','0','1800x1100x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    results=[]
    try:
        time.sleep(.4)
        with tempfile.TemporaryDirectory(prefix='farm-diy-capture-') as profile:
            env=dict(os.environ,DISPLAY=display,LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=profile,APPDATA=profile)
            if before:
                project=Path(profile)/'baseline';project.mkdir()
                with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['git','archive','ea3204b'],cwd=ROOT))) as archive:archive.extractall(project)
                (OUT/'before').mkdir(parents=True,exist_ok=True)
                (project/'before.gd').write_text(BEFORE.replace('%OUTPUT%',str(OUT/'before/farm_full_spring.png')))
                (project/'before.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://before.gd" id="1"]\n[node name="Before" type="Node"]\nscript = ExtResource("1")\n')
                imported=subprocess.run([str(ENGINE),'--headless','--path',str(project),'--import'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
                (ROOT/'builds/farm-diy-baseline-import.log').write_text(imported.stdout)
                if imported.returncode or 'ERROR:' in imported.stdout:raise RuntimeError('Before import failed')
                result=subprocess.run([str(ENGINE),'--path',str(project),'--audio-driver','Dummy','--fixed-fps','60','--max-fps','0','res://before.tscn'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
                (ROOT/'builds/farm-diy-baseline-window.log').write_text(result.stdout)
                if result.returncode or 'ERROR:' in result.stdout:raise RuntimeError('Before capture failed')
                print('Before ea3204b actual window saved');return
            scenes=[('editor','res://builds/farm_diy_window_capture.tscn')]
            if not editor_only:scenes += [('production','res://tests/farm_diy_production_runner.tscn'),('business','res://tests/farm_layout_business_runner.tscn')]
            if production_only:scenes=[('production','res://tests/farm_diy_production_runner.tscn')]
            for name,scene in scenes:
                flag='--capture-diy-production' if name=='production' else '--capture'
                result=subprocess.run([str(ENGINE),'--path',str(ROOT),'--audio-driver','Dummy','--fixed-fps','60','--max-fps','0',scene,'--',flag],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
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
    report=ROOT/'builds/farm-diy-final-windows.json'
    if (editor_only or production_only) and report.exists():
        previous=json.loads(report.read_text());names={row['name'] for row in results};results += [row for row in previous if row['name'] not in names]
    report.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before',action='store_true');parser.add_argument('--editor-only',action='store_true');parser.add_argument('--production-only',action='store_true')
    args=parser.parse_args();capture(args.before,args.editor_only,args.production_only)
