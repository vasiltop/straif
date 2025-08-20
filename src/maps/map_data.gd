class_name MapData extends Resource

@export var name: String
@export var tier: int
@export var mid: int
@export var modes: Array
@export var medals: Dictionary # mode_name -> [bronze, silver, gold, plat, author]
@export var image: Texture2D

func _init(
	map_name := "", 
	map_tier := 0, 
	map_id := 0,
	modes := [],
	medals := {},
	image: Texture2D = null
	) -> void:
	self.name = map_name
	self.tier = map_tier
	self.mid = map_id
	self.modes = modes
	self.medals = medals
	self.image = image
