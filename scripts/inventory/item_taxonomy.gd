class_name ItemTaxonomy
extends RefCounted
## Classification and permanent-tool presentation, never a second inventory.
const TOOLS: Array[String]=["hoe","water","hand","axe","pickaxe","fishing_rod"]
const TOOL_INDEX := {"hoe":0,"water":1,"hand":2,"axe":6,"pickaxe":7,"fishing_rod":8}
const TOOL_NAMES := {"hoe":"锄头","water":"水壶","hand":"采收","axe":"斧头","pickaxe":"镐子","fishing_rod":"鱼竿"}
const CATEGORIES: Array[String]=["all","tools","seeds","produce","food","materials","processed","furniture","quest","other"]
const LABELS := {"all":"全部","tools":"工具","seeds":"种子","produce":"农作物","food":"料理","materials":"材料","processed":"加工品","furniture":"家具建造","quest":"任务收藏","other":"其他"}
static var tool_icons: Dictionary={}

static func is_permanent_tool(id: String) -> bool: return id in TOOLS
static func title(id: String) -> String: return str(TOOL_NAMES[id]) if is_permanent_tool(id) else Catalog.item_name(id)
static func texture(id: String) -> Texture2D:
	if not is_permanent_tool(id): return ItemPresentation.texture(id)
	if not tool_icons.has(id):
		if id=="fishing_rod": tool_icons[id]=load("res://assets/fishing/fishing_rod.png")
		else:
			var icon:=AtlasTexture.new();icon.atlas=load("res://assets/ui/tools.png");icon.region=Rect2(int(TOOL_INDEX[id])*32,0,32,32);tool_icons[id]=icon
		tool_icons[id]=ItemPresentation.tool_badge(tool_icons[id])
	return tool_icons[id]

static func category(id: String) -> String:
	if is_permanent_tool(id): return "tools"
	var item: Dictionary=Catalog.items.get(id,{})
	var kind: String=str(item.get("kind",""));var group: String=str(item.get("category",""))
	if kind=="equipment": return "tools"
	if group=="seed" or kind=="sapling": return "seeds"
	if group=="crop" or kind=="fruit": return "produce"
	if kind=="food": return "food"
	if kind=="processed": return "processed"
	if kind in ["device","decoration"]: return "furniture"
	if kind in ["relic","collection","souvenir","quest"] or item.get("quest_item",false): return "quest"
	if kind in ["material","ingredient","animal_product","feed"] or group in ["material","materials","aquaculture"]: return "materials"
	return "other"

static func is_protected(id: String) -> bool:
	return is_permanent_tool(id) or category(id)=="quest" or Catalog.items.get(id,{}).get("protected",false)

static func comes_before(a: Dictionary, b: Dictionary) -> bool:
	var ac: int=CATEGORIES.find(category(str(a.item)));var bc: int=CATEGORIES.find(category(str(b.item)))
	if ac!=bc: return ac<bc
	if is_permanent_tool(str(a.item))!=is_permanent_tool(str(b.item)): return is_permanent_tool(str(a.item))
	if is_permanent_tool(str(a.item)) and is_permanent_tool(str(b.item)): return TOOLS.find(str(a.item))<TOOLS.find(str(b.item))
	if category(str(a.item))=="seeds":
		var a_seed: bool=str(a.item).ends_with("_seed") and Catalog.crops.has(str(a.item).trim_suffix("_seed"))
		var b_seed: bool=str(b.item).ends_with("_seed") and Catalog.crops.has(str(b.item).trim_suffix("_seed"))
		if a_seed!=b_seed: return a_seed
		if a_seed: return Catalog.crops.keys().find(str(a.item).trim_suffix("_seed"))<Catalog.crops.keys().find(str(b.item).trim_suffix("_seed"))
	var order: int=title(str(a.item)).naturalnocasecmp_to(title(str(b.item)))
	return str(a.item)<str(b.item) if order==0 else order<0

static func usable(id: String) -> bool:
	return is_permanent_tool(id) or (id.ends_with("_seed") and Catalog.crops.has(id.trim_suffix("_seed"))) or Recovery.FOOD.has(id) or Kitchen.data.items.get(id,{}).get("kind","")=="food" or id in ["dried_fish","fish_soup","fishing_hook"]

static func description(id: String) -> String:
	if is_permanent_tool(id):
		return {"hoe":"开垦合法土地；先选锄头，再点击目标地块。","water":"给尚未浇水的农田浇水。","hand":"采收成熟作物，也可以点击人物和设施互动。","axe":"砍伐树木、树桩和灌木；沿用现有工具升级。","pickaxe":"清理石头；大石堆仍需要对应工具升级。","fishing_rod":"到合法水岸抛竿；鱼饵、鱼钩和鱼竿等级沿用当前配置。"}[id]
	if id.ends_with("_seed") and Catalog.crops.has(id.trim_suffix("_seed")): return ProductionInfo.seed_hint(id.trim_suffix("_seed"))
	return ProductionInfo.uses(id)
