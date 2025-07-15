extends Node

const PATH := "user://settings.cfg"

var config := ConfigFile.new()

func _ready() -> void:
	if FileAccess.file_exists(PATH):
		config.load(PATH)
	else:
		reset_to_defaults()
		save()
	
	change_display_mode(value("Display", "mode") as int)
	AudioServer.set_bus_volume_db(0, value("Audio", "master_volume") as float)

func save() -> void:
	config.save(PATH)

func reset_to_defaults() -> void:
	config.set_value("Controls", "sensitivity", 1.0)
	config.set_value("Display", "mode", 0)
	config.set_value("Display", "max_fps", 255)
	config.set_value("Audio", "master_volume", -10.0)

func update(section: String, key: String, value: Variant) -> void:
	config.set_value(section, key, value)

func value(section: String, key: String) -> Variant:
	return config.get_value(section, key)

func change_display_mode(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
