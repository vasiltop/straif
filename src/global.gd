class_name GlobalManager extends Node

const APP_ID := 3850480

var server_bridge: ServerBridge
var map_manager: MapManager
var settings_manager: Settings
var game_manager: GameManager

func _ready() -> void:
	DisplayServer.window_set_title("Straif")
	add_child(game_manager)
	var init_res := Steam.steamInitEx(APP_ID, true)

	if init_res.status != Steam.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
		Info.alert("Failed to initialize Steam\n Make sure it is running.")
	
	server_bridge = ServerBridge.new()
	map_manager = MapManager.new()
	settings_manager = Settings.new()
	game_manager = GameManager.new()
	
	map_manager.load_maps()
	get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
