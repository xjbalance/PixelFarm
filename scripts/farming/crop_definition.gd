class_name CropDefinition
extends Resource
## 新作物只需添加 .tres 并登记目录，不改变农田的生长算法。
@export var id: String
@export var display_name: String
@export var seed_price: int = 10
@export var sell_price: int = 30
@export var growth_days: int = 2
@export var atlas_row: int = 0
@export var stages: int = 4
@export var harvest_quantity: int = 1
@export var texture_path: String = "res://assets/crops/crops.png"
