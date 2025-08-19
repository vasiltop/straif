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
		var map_times: Array = map.times
		
		const IMAGES_LOCATION := "res://images/screenshots/"
		var image: Texture2D = load(IMAGES_LOCATION + map_name + ".png")
		
		var map_times_float: Array[float]
		for time: float in map_times:
			map_times_float.append(time)
		
		var map_data := MapData.new(map_name, map_tier, i, map_times_float, image)
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
