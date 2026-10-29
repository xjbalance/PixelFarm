class_name ItemPresentation
extends RefCounted
## 展示层复用原物品图；无原图的材料采用轻量原创像素符号，不注册新物品。
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if textures.has(id): return textures[id]
	var result: Texture2D
	if Catalog.items.get(id,{}).has("icon"):
		result=load(str(Catalog.items[id].icon))
	elif (Catalog.crops.has(id) or (id.ends_with("_seed") and Catalog.crops.has(id.trim_suffix("_seed")))) and ResourceLoader.exists("res://assets/harvest/items/"+id+".png"):
		result=load("res://assets/harvest/items/"+id+".png")
	elif Catalog.crops.has(id):
		var atlas:=AtlasTexture.new();atlas.atlas=load("res://assets/crops/crops.png")
		atlas.region=Rect2(96,Catalog.crops[id].atlas_row*40,32,40);result=atlas
	elif id.ends_with("_seed") and Catalog.crops.has(id.trim_suffix("_seed")):
		result=load("res://assets/ui/seed.png")
	else:
		var category: String=Catalog.items.get(id,{}).get("category","")
		var folder: String="festivals" if category=="festival" else category
		var path: String="res://assets/"+folder+"/"+id+".png"
		if ResourceLoader.exists(path): result=load(path)
		else: result=material_symbol(id)
	textures[id]=result
	return result

static func description(id: String) -> String:
	if HarvestCatalog.data().crops.has(id): return str(HarvestCatalog.data().crops[id].description)
	if Catalog.crops.has(id): return "可出售、食用或交付委托；食用后恢复%d体力。" % int(Recovery.FOOD.get(id,0))
	if id.ends_with("_seed") and Catalog.crops.has(id.trim_suffix("_seed")):
		return "%s季种植；每天浇水，%d日成熟。先装备再点空的翻土地。" % [HarvestCatalog.season_text(id.trim_suffix("_seed")),int(Catalog.crops[id.trim_suffix("_seed")].growth_days)]
	return str(Catalog.items.get(id,{}).get("description","收藏或任务物品；请到对应设施查看用途。"))

static func material_symbol(id: String) -> Texture2D:
	var picture:=Image.create(24,24,false,Image.FORMAT_RGBA8);picture.fill(Color.TRANSPARENT)
	var tint: Color={"wood":Color("b58a57"),"stone":Color("969b94"),"copper_ore":Color("ba8665"),"iron_ore":Color("879caa"),"crystal":Color("9ccbbb"),"starlight_ore":Color("a6a2d0"),"copper_bar":Color("d39b73"),"iron_bar":Color("a1afb4"),"star_alloy":Color("b5b2d5"),"ancient_shard":Color("c3b583"),"star_fragment":Color("b6acd4")}.get(id,Color("b8ab88"))
	if id=="wood":
		for y in [5,12]:
			picture.fill_rect(Rect2i(3,y,18,6),tint.darkened(.25));picture.fill_rect(Rect2i(4,y,16,4),tint)
			picture.fill_rect(Rect2i(6,y+1,10,1),tint.lightened(.2))
	elif id.ends_with("_bar") or id=="star_alloy":
		picture.fill_rect(Rect2i(3,9,18,9),tint.darkened(.3));picture.fill_rect(Rect2i(5,6,14,9),tint)
		picture.fill_rect(Rect2i(6,7,11,2),tint.lightened(.25))
	else:
		for y in range(3,21):
			var half: int=mini(8,mini(y-1,23-y))
			picture.fill_rect(Rect2i(12-half,y,half*2,1),tint.darkened(.18))
		picture.fill_rect(Rect2i(9,6,4,9),tint.lightened(.22));picture.fill_rect(Rect2i(7,14,4,3),tint)
	return ImageTexture.create_from_image(picture)
