extends Node

const APP_ID := 3850480

var server_bridge: ServerBridge
var map_manager: MapManager
var settings_manager: Settings
var game_manager: GameManager
var is_server: bool
var offline_playtest: bool

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	if OS.has_feature("editor_runtime"):
		args = args.slice(2)

	print(args)

	is_server = len(args) > 2
	offline_playtest = is_offline_playtest_mode(OS.get_cmdline_user_args())

	if offline_playtest and not is_server:
		print("Offline playtest mode active: skipping Steam Web API auth ticket request.")

	if not is_server:
		var init_res := Steam.steamInitEx(APP_ID, true)

		if init_res.status != Steam.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
			Info.alert("Failed to initialize Steam\n Make sure it is running.")

		await ShotVfxPrewarmer.warm_up()
	
	map_manager = MapManager.new()
	server_bridge = ServerBridge.new()
	game_manager = GameManager.new(is_server, not offline_playtest)
	add_child(game_manager)
	
	multiplayer.peer_connected.connect(game_manager.on_peer_connected)
	multiplayer.peer_disconnected.connect(game_manager.on_peer_disconnected)
	multiplayer.connected_to_server.connect(game_manager.on_connected_to_server)
	multiplayer.connection_failed.connect(game_manager.on_connection_failed)
	multiplayer.server_disconnected.connect(game_manager.on_server_disconnected)
	
	if is_server:
		game_manager.init_server(args[1], int(args[2]), int(args[3]), args[4])
		return

	settings_manager = Settings.new()
	
	map_manager.load_maps()
	get_tree().call_deferred("change_scene_to_file", "res://src/menus/main/main_menu.tscn")

func mp_print(message: String) -> void:
	print("[%d]: %s" % [id(), message])

func id() -> int:
	if not multiplayer.multiplayer_peer: return 1
	
	return multiplayer.get_unique_id()

func mp() -> bool:
	return multiplayer.multiplayer_peer != null

func is_sv() -> bool:
	return is_server

func is_offline_playtest_mode(user_args: PackedStringArray) -> bool:
	return user_args.has("--offline-playtest")
