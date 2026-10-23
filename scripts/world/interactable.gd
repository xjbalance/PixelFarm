extends Node2D
@export var kind: String = "home"
@export var label: String = "回家休息"

func _ready() -> void:
	add_to_group("interactables")

func interact() -> void:
	Events.interaction_requested.emit(kind)

func prompt() -> String:
	return label
