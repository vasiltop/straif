class_name Maps extends Node

@export var maps: Array[MapData]

func get_map_with_id(mid: int) -> MapData:
	for map in maps:
		if map.mid == mid:
			return map

	return null
