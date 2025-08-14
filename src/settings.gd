extends Node

const PATH := "user://settings.cfg"
const SETTINGS_VERSION := 3

var config := ConfigFile.new()
var default_keybinds: Dictionary[String, Keybind] = {
	"left" = Keybind.new(KEY_A),
	"right" = Keybind.new(KEY_D),
	"up" = Keybind.new(KEY_W),
	"down" = Keybind.new(KEY_S),
	"jump" = Keybind.new(KEY_SPACE),
	"climb" = Keybind.new(KEY_SPACE),
	"main_menu" = Keybind.new(KEY_ESCAPE),
	"restart" = Keybind.new(KEY_R),
	"inspect" = Keybind.new(KEY_E),
	"interact" = Keybind.new(KEY_F),
	"leaderboard"  = Keybind.new(KEY_TAB),
	"attack" = Keybind.new(MOUSE_BUTTON_LEFT, true)
}

class Keybind:
	var is_mouse: bool
	var code: int
	
	func _init(code: int, is_mouse := false) -> void:
		self.is_mouse = is_mouse
		self.code = code

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
	config.set_value("Display", "max_fps", 1000)
	config.set_value("Audio", "master_volume", -10.0)
	config.set_value("Game", "version", SETTINGS_VERSION)
	
	for action in get_custom_actions():
		config.set_value("Controls", action, serialize_keybind(default_keybinds[action]))

func serialize_keybind(keybind: Keybind) -> String:
	var res := ""
	
	if keybind.is_mouse:
		res += "mouse_"
	
	res += str(keybind.code)
	
	return res

func deserialize_keybind(string: String) -> Keybind:
	var is_mouse := string.begins_with("mouse_")
	
	if is_mouse:
		string = string.substr(len("mouse_"))
	
	var code := int(string)
	
	return Keybind.new(code, is_mouse)

func event_to_keybind(event: InputEvent) -> Keybind:
	var keybind := Keybind.new(0)
	
	if event is InputEventKey:
		var iek: InputEventKey = event
		keybind.code = iek.keycode
		
	elif event is InputEventMouseButton:
		var iem: InputEventMouseButton = event
		keybind.is_mouse = true
		keybind.code = iem.button_index
		
	return keybind

func change_action_to_keybind(action_name: String, keybind: Keybind) -> void:
	var ev: InputEvent
	
	if keybind.is_mouse:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = keybind.code
		ev = mouse_event
	else:
		var key_event := InputEventKey.new()
		key_event.keycode = keybind.code
		ev = key_event

	change_action_to_event(action_name, ev)

func change_action_to_event(action_name: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
	config.set_value("Controls", action_name, serialize_keybind(event_to_keybind(event)))

func update_input_map() -> void:
	for action in get_custom_actions():
		var value: String = value("Controls", action)
		change_action_to_keybind(action, deserialize_keybind(value))

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
