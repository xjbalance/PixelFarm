class_name MarriagePreparation
extends RefCounted
## Read existing achievements only. No second counters, rewards or save fields.
const PATH: String="res://resources/story/marriage_preparation.json"
static var _data: Dictionary={}

static func data() -> Dictionary:
	if _data.is_empty(): _data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data

static func goals() -> Array[Dictionary]:
	var rules:=data()
	var stories: int=0
	var people: Array[String]=[]
	for person in ["linya","zhou","ahe"]:
		var completed: int=0
		var required: int=0
		for id in rules.villager_stories:
			if Social.definition(str(id)).get("person","")!=person: continue
			required+=1
			if id in Social.state.completed: completed+=1;stories+=1
		people.append("%s %d/%d" % [Social.data.people[person].name,completed,required])
	var dishes: int=0
	var missing_dishes: Array[String]=[]
	for id in rules.recipes:
		if int(Kitchen.state.cooked.get(id,0))>0: dishes+=1
		else: missing_dishes.append(str(Kitchen.data.recipes[id].name))
	var fish: int=0
	var missing_fish: Array[String]=[]
	for id in rules.fish_species:
		if int(Fishing.state.counts.get(id,0))>0: fish+=1
		else: missing_fish.append(str(Fishing.data.species[id].name))
	var restored: bool=bool(LakeEcology.state.restored)
	return [
		{"id":"village_stories","short_label":"村民个人支线","ready":stories==rules.villager_stories.size(),"label":"邻里同行 · 完成三位村民的9项个人支线","detail":"%s。到人物关系页查看下一项约定；已有完成记录直接认可。" % " · ".join(people),"current":stories,"target":rules.villager_stories.size()},
		{"id":"cooking","short_label":"5种家常料理","ready":dishes==rules.recipes.size(),"label":"家常手艺 · 亲手制作5种料理","detail":"已制作 %d/%d。%s" % [dishes,rules.recipes.size(),"所有料理的制作记录已齐，不用保留或再次交付成品。" if missing_dishes.is_empty() else "待制作："+"、".join(missing_dishes)+"。购买、赠品和旧库存不计制作。"],"current":dishes,"target":rules.recipes.size()},
		{"id":"fish_collection","short_label":"7种鱼类图鉴","ready":fish==rules.fish_species.size(),"label":"河湾钓手 · 亲手钓获并领取7种鱼","detail":"钓获图鉴 %d/%d。%s" % [fish,rules.fish_species.size(),"钓获记录已齐，不用保留或交付鱼。" if missing_fish.is_empty() else "尚缺："+"、".join(missing_fish)+"。以自由钓鱼领取记录为准。"],"current":fish,"target":rules.fish_species.size()},
		{"id":"ecology","short_label":"湖泊生态修复","ready":restored,"label":"清水归湾 · 完成湖泊生态修复","detail":"生态修复已完成，记录永久认可。" if restored else "清理湖岸、栽种水草并修好循环水道后，在湖泊生态台确认完成修复。仅达到高健康度还不算完成。","current":1 if restored else 0,"target":1}
	]
