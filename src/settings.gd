extends Node

const PATH := "user://settings.cfg"
const SETTINGS_VERSION := 1

var config := ConfigFile.new()
var default_keybinds: Dictionary[String, int] = {
	"left" = KEY_A,
	"right" = KEY_D,
	"up" = KEY_W,
	"down" = KEY_S,
	"jump" = KEY_SPACE,
	"main_menu" = KEY_ESCAPE,
	"restart" = KEY_R,
	"inspect" = KEY_E,
	"interact" = KEY_F,
	"leaderboard"  = KEY_TAB,
}

func _ready() -> void:
	if FileAccess.file_exists(PATH):
		load_settings()
	else:
		reset_to_defaults()
		save()
	
	change_display_mode(value("Display", "mode") as int)
	Engine.max_fps = value("Display", "max_fps")
	AudioServer.set_bus_volume_db(0, value("Audio", "master_volume") as float)
	update_input_map()

func load_settings() -> void:
	config.load(PATH)
	
	var version: Variant = value("Game", "version")
	
	if version == null or version != SETTINGS_VERSION:
		reset_to_defaults()
		save()
		return

func get_custom_actions() -> Array[String]:
	var all_actions := InputMap.get_actions()

	var custom_actions: Array[String] = []
	for action in all_actions:
		if not action.begins_with("ui_"):
			custom_actions.append(action)
			
	return custom_actions

func get_keybind_string(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	var first := events[0]
	return first.as_text()
	
func save() -> void:
	config.save(PATH)

func reset_to_defaults() -> void:
	config.set_value("Controls", "sensitivity", 1.0)
	config.set_value("Display", "mode", 0)
	config.set_value("Display", "max_fps", 255)
	config.set_value("Audio", "master_volume", -10.0)
	config.set_value("Game", "version", SETTINGS_VERSION)
	
	for action in get_custom_actions():
		config.set_value("Controls", action, default_keybinds[action])
		
func change_keybind(action_name: String, new_key: Key) -> void:
	InputMap.action_erase_events(action_name)
	
	var new_event := InputEventKey.new()
	new_event.keycode = new_key
	InputMap.action_add_event(action_name, new_event)
	config.set_value("Controls", action_name, new_key)
	
func update_input_map() -> void:
	for action in get_custom_actions():
		var value: int = value("Controls", action)
		change_keybind(action, value)

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
