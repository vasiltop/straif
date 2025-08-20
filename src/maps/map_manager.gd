class_name MapManager

const MAPS_FILE_PATH := "res://maps.json"
var maps: Array[MapData]

func load_maps() -> Array[MapData]:
	var file := FileAccess.open(MAPS_FILE_PATH, FileAccess.READ)
	var json: Dictionary = JSON.parse_string(file.get_as_text())
	var map_list: Array = json.maps
	
	for i in range(len(map_list)):
		var map: Dictionary = map_list[i]
		var map_name: String = map.name
		var map_tier: int = map.tier
		
		const IMAGES_LOCATION := "res://images/screenshots/"
		var image: Texture2D = load(IMAGES_LOCATION + map_name + ".png")
		
		var modes: Array = map.modes
		var mode_times := {}
		
		for mode: String in modes:
			var mode_medal_times: Array = map["medals_" + mode]
			mode_times[mode] = mode_medal_times

		var map_data := MapData.new(map_name, map_tier, i, modes, mode_times, image)
		maps.append(map_data)
		
	return maps

func get_map_with_id(mid: int) -> MapData:
	for map in maps:
		if map.mid == mid:
			return map

	return null

func get_map_with_name(mname: String) -> MapData:
	for map in maps:
		if map.name == mname:
			return map
			
	return null
