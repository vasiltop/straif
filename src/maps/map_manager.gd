class_name MapManager

const BASE_MAP_PATH := "res://src/maps/"
const MAPS_FILE_PATH := "res://maps.json"
var maps: Array[MapData]

func get_map_image(map_name: String) -> Texture2D:
	const IMAGES_LOCATION := "res://images/screenshots/"
	return load(IMAGES_LOCATION + map_name + ".png")

func load_maps() -> Array[MapData]:
	var file := FileAccess.open(MAPS_FILE_PATH, FileAccess.READ)
	var json: Dictionary = JSON.parse_string(file.get_as_text())
	var map_list: Array = json.maps
	
	for i in range(len(map_list)):
		var map: Dictionary = map_list[i]
		var map_name: String = map.name
		var map_tier: int = map.tier

		var image: Texture2D = get_map_image(map_name)
		
		var modes: Array = map.modes
		var mode_times := {}
		
		for mode: String in modes:
			var mode_medal_times: Array = map["medals_" + mode]
			mode_times[mode] = mode_medal_times

		var map_data := MapData.new(map_name, map_tier, i, modes, mode_times, image)
		maps.append(map_data)
		
	return maps

func switch_to_map(mode: String, name: String) -> void:
	var path := BASE_MAP_PATH + mode + "/" + name + ".tscn"
	Global.get_tree().change_scene_to_file(path)

func get_full_map_path(mode: String, map_name: String) -> String:
	var path := BASE_MAP_PATH + mode + "/"
	return path + map_name

func get_random_map(mode: String) -> String:
	var path := BASE_MAP_PATH + mode + "/"
	var dir_access := DirAccess.open(path)

	var files := dir_access.get_files()
	var index := randi_range(0, len(files) - 1)
	var map_scene_name := files[index]

	return map_scene_name

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
