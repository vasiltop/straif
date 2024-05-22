extends GridContainer

var level_button = preload("res://menus/main/level_button.tscn")
var lobby_button = preload("res://menus/main/lobby_button.tscn")

const map_data = {
	"bhop_0x": {
		"mapper": "m",
		"difficulty": 3
	},
	"bhop_rookie": {
		"mapper": "munost",
		"difficulty": 1
	},
	"bhop_rookie2": {
		"mapper": "munost",
		"difficulty": 1
	},
	"bhop_dawn": {
		"mapper": "munost",
		"difficulty": 2
	},
	"bhop_purge": {
		"mapper": "munost",
		"difficulty": 2
	},
	"bhop_swift": {
		"mapper": "Roboglow",
		"difficulty": 1
	},
	"bhop_fog": {
		"mapper": "munost",
		"difficulty": 2
	},
	"lj_longjump": {
		"mapper": "munost",
		"difficulty": 0
	},
	"kz_gunner": {
		"mapper": "munost",
		"difficulty": 1
	},
	"bhop_tutorial": {
		"mapper": "munost",
		"difficulty": 1
	},
	"bhop_taurus": {
		"mapper": "munost",
		"difficulty": 4
	},
}

func _ready():
	Steam.lobby_match_list.connect(on_lobbies_received)
	set_gamemode_bhop()

func set_gamemode_bhop():
	var maps = get_maps_with_prefix("bhop")
	create_level_buttons(maps)
	
func set_gamemode_longjump():
	var maps = get_maps_with_prefix("lj")
	create_level_buttons(maps)
	
func set_gamemode_kz():
	var maps = get_maps_with_prefix("kz")
	create_level_buttons(maps)

func create_level_buttons(maps: Array):
	remove_children()
	
	for map in maps:
		var instance = level_button.instantiate()
		instance.set_label(map)
		instance.set_difficulty(map_data[map]['difficulty'])
		instance.set_mapper(map_data[map]['mapper'])
		add_child(instance)
		
func remove_children():
	for n in get_children():
		remove_child(n)
		n.queue_free() 

func get_maps_with_prefix(prefix: String) -> Array:
	var dir = DirAccess.open("res://levels")
	if not dir: return []
	
	var result = []
	
	dir.list_dir_begin()
	
	var file_name = dir.get_next()
	while file_name != "":
		var split_name = file_name.split("_")
		
		if split_name[0] == prefix:
			result.append(file_name.left(file_name.length() - ".tscn".length()))

		file_name = dir.get_next()

	return result

func show_lobbies():
	remove_children()
	Steam.requestLobbyList()

func on_lobbies_received(lobbies: Array):
	for lobby_id in lobbies:
		var name = Steam.getLobbyData(lobby_id, "name")
		if name == "": continue
		
		var instance = lobby_button.instantiate()
		instance.set_label(name)
		instance.set_id(lobby_id)
		add_child(instance)

