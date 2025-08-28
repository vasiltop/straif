extends Node

const APP_ID := 3850480

var server_bridge: ServerBridge
var map_manager: MapManager
var settings_manager: Settings
var game_manager: GameManager

func _ready() -> void:
	var args := OS.get_cmdline_args()
	var is_server := len(args) > 1
	
	if not is_server:
		var init_res := Steam.steamInitEx(APP_ID, true)

		if init_res.status != Steam.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
			Info.alert("Failed to initialize Steam\n Make sure it is running.")
	
	map_manager = MapManager.new()
	server_bridge = ServerBridge.new()
	game_manager = GameManager.new()
	add_child(game_manager)
	
	multiplayer.peer_connected.connect(game_manager.on_peer_connected)
	multiplayer.peer_disconnected.connect(game_manager.on_peer_disconnected)
	multiplayer.connected_to_server.connect(game_manager.on_connected_to_server)
	multiplayer.connection_failed.connect(game_manager.on_connection_failed)
	multiplayer.server_disconnected.connect(game_manager.on_server_disconnected)
	
	if is_server:
		game_manager.init_server(args[1], int(args[2]), int(args[3]), args[4])
		return

	DisplayServer.window_set_title("Straif")

	settings_manager = Settings.new()
	
	map_manager.load_maps()
	get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")

func mp_print(message: String) -> void:
	print("[%d]: %s" % [id(), message])

func id() -> int:
	if not multiplayer.multiplayer_peer: return 1
	
	return multiplayer.get_unique_id()

func mp() -> bool:
	return multiplayer.multiplayer_peer != null

func is_sv() -> bool:
	return multiplayer.is_server()
