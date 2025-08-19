class_name MapData extends Resource

@export var name: String
@export var tier: int
@export var mid: int
@export var medal_times: Array[float] # [bronze, silver, gold, plat, author]
@export var image: Texture2D

func _init(
	map_name: String = "", 
	map_tier: int = 0, 
	map_id: int = 0,
	map_medal_times: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0],
	image: Texture2D = null
	) -> void:
	self.name = map_name
	self.tier = map_tier
	self.mid = map_id
	self.medal_times = map_medal_times
	self.image = image
