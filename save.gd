extends Node

var previous_run_replay = null

var data: Dictionary =  {
	"bhop_rookie": {
		"pr": null,
		"replay": null,
	},
	"bhop_rookie2": {
		"pr": null,
		"replay": null,
	},
	"bhop_dawn": {
		"pr": null,
		"replay": null,
	},
	"bhop_purge": {
		"pr": null,
		"replay": null,
	},
	"bhop_swift": {
		"pr": null,
		"replay": null,
	},
	"bhop_fog": {
		"pr": null,
		"replay": null,
	},
	"lj_longjump": {
		"pr": null,
		"replay": null,
	},
	"kz_gunner": {
		"pr": null,
		"replay": null,
	},
}

func _ready():
	load_data()

func load_data():
	var save_file = FileAccess.open(Settings.save_file, FileAccess.READ)
	
	if save_file == null:
		save_data()
	else:
		var text = save_file.get_as_text()
		var json = JSON.parse_string(text)
		data = json

func save_data():
	var save_file = FileAccess.open(Settings.save_file, FileAccess.WRITE)
	var json = JSON.stringify(data)
	save_file.store_string(json)

func get_action_string(name: String):
	return InputMap.action_get_events(name)[0].as_text().split(" ")[02]
