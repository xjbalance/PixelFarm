extends Node
## Persistent expansion state; legacy Kitchen queues keep their original settlement dates.
signal changed
var state: Dictionary=defaults()
var game: Node
var busy: bool=false
func defaults() -> Dictionary:
	return {"version":1,"jobs":{},"orchard":{},"next_job":1,"claimed":[],"legacy_installed":[],"selected_seed":"wheat_seed"}
func snapshot() -> Dictionary: return state.duplicate(true)
func restore(raw: Dictionary) -> void:
	state=AbyssSaveSchema.canonical(raw).duplicate(true);busy=false
	apply_seed();changed.emit()
func apply_seed() -> void:
	GameState.tools[5]=str(state.selected_seed)
	GameState.tool_names[5]=Catalog.item_name(str(state.selected_seed).trim_suffix("_seed"))
func select_seed(id: String) -> void:
	if not Catalog.crops.has(id) or Inventory.count(id+"_seed")<1: return
	if id in ["carrot","potato"]: GameState.select_tool(GameState.tools.find(id+"_seed"));return
	state.selected_seed=id+"_seed";apply_seed();GameState.select_tool(5);Events.progress_committed.emit()
func validate(raw: Variant, _save: Dictionary) -> bool:
	if not AquacultureSaveSchema.exact(raw,defaults().keys()): return false
	if not FarmSaveSchema.whole(raw.version,1,1) or not raw.selected_seed is String or not Catalog.crops.has(raw.selected_seed.trim_suffix("_seed")) or not raw.selected_seed.ends_with("_seed"): return false
	return raw.jobs is Dictionary and raw.jobs.is_empty() and raw.orchard is Dictionary and raw.orchard.is_empty() and raw.next_job==1 and raw.claimed==[] and raw.legacy_installed==[]
