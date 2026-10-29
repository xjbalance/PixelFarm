extends "res://tests/runner.gd"
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();game.persistence_enabled=false;add_child(game)
	GameClock.running=false;GameWeather.enabled=false;game.get_node("Audio").muted=true
	await frames(8);game.tutorial.restore(GameTutorial.defaults(true))
	for i in range(3):
		var id: String=["carrot","potato","wheat"][i]
		game.farm.plots["%d,17" % (18+i)]={"crop":id,"days":Catalog.crops[id].growth_days,"watered":true}
	for i in range(4):
		game.farm.plots["%d,18" % (18+i)]={"crop":"","days":0,"watered":true}
		var sprite:=Sprite2D.new();var tex:=AtlasTexture.new();tex.atlas=load("res://assets/harvest/crops/strawberry.png");tex.region=Rect2(i*32,0,32,40)
		sprite.texture=tex;sprite.position=Vector2((18+i)*32+16,18*32+11);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;game.farm.add_child(sprite)
	game.farm.queue_redraw();game.player.global_position=Vector2(704,608);game.camera_rig.follow_now()
	var machine:=Sprite2D.new();machine.texture=load("res://assets/harvest/stations/jam_pot.png");machine.position=Vector2(816,520);machine.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;game.world.actors.add_child(machine)
	var panel:=PanelContainer.new();panel.theme=load("res://resources/ui/river_theme.tres");panel.position=Vector2(180,380);panel.size=Vector2(920,150);game.hud.safe.add_child(panel)
	var col:=VBoxContainer.new();panel.add_child(col);col.add_child(FarmUIStyle.label("丰收工坊 · 原素材与扩展样板同屏",22))
	var row:=HBoxContainer.new();col.add_child(row)
	for spec in [["flour","原有面粉","res://assets/kitchen/flour.png"],["potato_bread","原有面包","res://assets/kitchen/potato_bread.png"],["egg","原有鸡蛋","res://assets/livestock/egg.png"],["strawberry","草莓","res://assets/harvest/items/strawberry.png"],["bread","麦香面包","res://assets/harvest/items/bread.png"],["mayonnaise","蛋黄酱","res://assets/harvest/items/mayonnaise.png"]]:
		var b:=FarmUIStyle.button(str(spec[1]),func(): pass,140);b.icon=load(str(spec[2]));b.expand_icon=true;b.add_theme_constant_override("icon_max_width",32);row.add_child(b)
	col.add_child(FarmUIStyle.label("田间上排：旧胡萝卜、土豆、小麦　下排：草莓四阶段　右侧：果酱锅",16))
	await frames(8);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/harvest-workshop/style-sample.png")
	game.get_node("Audio").stop_all();game.queue_free();await frames(4);get_tree().call_deferred("quit")
