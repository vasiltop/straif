extends Node

var data: Dictionary =  {
	"bhop_rookie": {
		"pr": null,
	},
	"bhop_rookie2": {
		"pr": null,
	},
	"bhop_dawn": {
		"pr": null,
	},
	"bhop_purge": {
		"pr": null,
	},
	"bhop_swift": {
		"pr": null,
	},
	"bhop_fog": {
		"pr": null,
	},
	"lj_longjump": {
		"pr": 0,
	},
	"kz_gunner": {
		"pr": null,
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
