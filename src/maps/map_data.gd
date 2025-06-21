class_name MapData extends Resource

@export var name: String
@export var tier: int

func _init(map_name: String = "", map_tier: int = 0) -> void:
	self.name = map_name
	self.tier = map_tier
