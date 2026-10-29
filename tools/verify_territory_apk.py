"""从实际 APK 提取资源，验证建造确认、权限与落盘；桌面执行不替代 Android 真机。"""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.search(r'^config/version="([^"]+)"', (ROOT / 'project.godot').read_text(), re.M).group(1)
PROBE = '''extends Node
var game: Node
func _ready() -> void: call_deferred("run")
func frames(count: int) -> void:
 for _i in range(count): await get_tree().physics_frame
func canonical(value: Dictionary) -> Dictionary:
 return AbyssSaveSchema.canonical(JSON.parse_string(JSON.stringify(value)))
func run() -> void:
 game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;game.save_path="user://territory-artifact-proof.json";add_child(game)
 GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true;await frames(8)
 game.tutorial.restore(GameTutorial.defaults(true));await frames(3)
 var expected: Dictionary=canonical(FarmSaveStore.snapshot(game));expected.erase("territory");expected.erase("farm_layout")
 var ok: bool=FarmSaveStore.VERSION==27 and FarmLayoutCatalog.fixtures().size()==64 and game.territory_world.maps.size()==5 and not Territory.unlocked("east_holding")
 ok=SchemeCAssets.catalog().size()==97 and ok
 for id in SchemeCAssets.catalog():
  var info: Dictionary=SchemeCAssets.definition(id)
  var art: Texture2D=SchemeCAssets.texture(id)
  ok=art!=null and art.get_size()==Vector2(info.size[0],info.size[1]) and ok
  ok=art!=null and art.resource_path.contains("/world_scheme_c/bright/sprites/") and ok
  if int(info.frames)>1:
   var animation: SpriteFrames=SchemeCAssets.animation(id)
   ok=animation!=null and animation.get_frame_count("loop")==4 and ok
   ok=animation!=null and animation.get_frame_texture("loop",0).resource_path.contains("/world_scheme_c/bright/animations/") and ok
 print("APK SCHEME C 97-ASSET LOAD: ","PASS" if ok else "FAIL")
 print("APK BRIGHT PALETTE STATIC/ANIMATED PATHS: ","PASS" if ok else "FAIL")
 ok=not WorldTravel.change(game,"east_holding") and not Territory.permission("village",Vector2i(6,6),"grass").allowed and ok
 ok=game.territory_editor.open() and ok
 game.territory_editor.choose_tool("stone_path")
 var cell:=Vector2i(-1,-1)
 for y in range(15,25):
  for x in range(3,14):
   if Territory.plan_terrain("farm",[Vector2i(x,y)],"stone_path").valid: cell=Vector2i(x,y);break
  if cell.x>=0: break
 game.persistence_enabled=true
 if cell.x>=0:
  ok=game.territory_editor.preview_at(cell) and game.territory_editor.confirm() and ok
 else: ok=false
 await frames(5)
 game.territory_editor.select_entity({"kind":"fixture","id":"home","name":"玩家住宅","stored":false})
 game.territory_editor.preview_at(Vector2i(20,5));await frames(5)
 ok=game.territory_editor.confirm() and ok
 await frames(5);game.territory_editor.cancel();game.save_game();await frames(3)
 var data: Dictionary=FarmSaveStore.read(game.save_path)
 ok=data.get("version")==27 and data.get("farm_layout")==FarmLayout.snapshot() and data.get("territory",{}).get("terrain",{}).get("farm",{}).get(TerritoryCatalog.key(cell))=="stone_path" and ok
 ok=data.get("farm_layout",{}).get("fixtures",{}).get("home",{}).get("cell")==[20,5] and FarmSaveStore.restore(game,data) and ok
 await frames(5)
 ok=FarmLayout.cell("fixture","home")==Vector2i(20,5) and ok
 print("APK FARM LAYOUT V27 MOVE/RESTORE: ","PASS" if ok else "FAIL")
 var after: Dictionary=canonical(FarmSaveStore.snapshot(game));after.erase("territory");after.erase("farm_layout")
 ok=after==expected and ok
 print("APK TERRITORY EDITOR SMOKE: ","PASS" if ok else "FAIL")
 game.persistence_enabled=false;game.get_node("Audio").stop_all();await get_tree().create_timer(.3).timeout;game.queue_free();await frames(4);get_tree().quit(0 if ok else 1)
'''

with tempfile.TemporaryDirectory(prefix='pixelworld-territory-apk-') as directory:
    folder = Path(directory)
    project = folder / 'game'
    project.mkdir()
    with zipfile.ZipFile(ROOT / f'builds/PixelWorld-{VERSION}-debug.apk') as apk:
        for name in apk.namelist():
            if not name.startswith('assets/') or name.endswith('/'):
                continue
            relative = Path(name).relative_to('assets')
            assert '..' not in relative.parts
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(apk.read(name))
    (project / 'territory_probe.gd').write_text(PROBE)
    (project / 'territory_probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://territory_probe.gd" id="1"]\n[node name="TerritoryProbe" type="Node"]\nscript = ExtResource("1")\n')
    result = subprocess.run([str(ROOT / '.tools/Godot_v4.3-stable_linux.x86_64'), '--headless', '--path', str(project), '--audio-driver', 'Dummy', '--fixed-fps', '60', 'res://territory_probe.tscn'], env=dict(os.environ, XDG_DATA_HOME=str(folder / 'profile'), APPDATA=str(folder / 'profile')), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
    (ROOT / 'builds/territory080-apk-editor.log').write_text(result.stdout)
    print(result.stdout)
    if result.returncode or 'APK TERRITORY EDITOR SMOKE: PASS' not in result.stdout or any(word in result.stdout for word in ['ERROR:', 'FAIL', 'instances leaked']):
        raise SystemExit('APK 领地功能验收失败')
