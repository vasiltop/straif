extends Node

const RuntimeOptions = preload("res://src/app/runtime_options.gd")
const Bootstrap = preload("res://src/app/bootstrap.gd")

var context: AppContext
var server_bridge: ServerBridge
var map_manager: MapManager
var settings_manager: Settings
var game_manager: GameManager
var is_server: bool
var offline_playtest: bool


func _ready() -> void:
	var args := _gather_launch_args()
	var allow_test_adapters := OS.has_feature("editor")

	var parse := RuntimeOptions.parse(args, allow_test_adapters)
	if not parse.is_ok():
		_abort_startup("Failed to parse launch arguments: %s" % parse.error)
		return

	var options := parse.options
	is_server = options.role == RuntimeOptions.Role.DEDICATED_SERVER
	offline_playtest = options.offline_playtest
	var is_connect_client := options.role == RuntimeOptions.Role.CONNECT_CLIENT

	if offline_playtest and not is_server:
		print("Offline playtest mode active: skipping Steam Web API auth ticket request.")

	map_manager = MapManager.new()
	server_bridge = ServerBridge.new()

	var build := Bootstrap.build(options, server_bridge, allow_test_adapters)
	if not build.is_ok():
		_abort_startup("Failed to build application context: %s" % build.error)
		return
	context = build.context

	game_manager = GameManager.new(context.options, context.server_registry, map_manager)
	game_manager.name = "GameManager"
	add_child(game_manager)

	multiplayer.peer_connected.connect(game_manager.on_peer_connected)
	multiplayer.peer_disconnected.connect(game_manager.on_peer_disconnected)
	multiplayer.connection_failed.connect(game_manager.on_connection_failed)
	multiplayer.server_disconnected.connect(game_manager.on_server_disconnected)

	if options.e2e and OS.has_feature("editor"):
		if not _start_e2e_control_client():
			return

	if is_server:
		game_manager.init_server()
		return

	if not options.e2e:
		await ShotVfxPrewarmer.warm_up()

	_start_identity(context.identity)

	settings_manager = Settings.new()

	map_manager.load_maps()

	if is_connect_client:
		game_manager.connect_to_server(options.connect_host, options.connect_port)
		return

	get_tree().call_deferred("change_scene_to_file", "res://src/menus/main/main_menu.tscn")


func _start_e2e_control_client() -> bool:
	var script_path := "res://tests/e2e/godot/control_client.gd"
	if not ResourceLoader.exists(script_path):
		_abort_startup("E2E control client script is unavailable at %s" % script_path)
		return false
	var control_script: Variant = load(script_path)
	if control_script == null:
		_abort_startup("Failed to load E2E control client script at %s" % script_path)
		return false
	var control_client: Variant = control_script.new()
	if not (control_client is Node):
		_abort_startup("E2E control client at %s is not a Node" % script_path)
		return false
	control_client.name = "E2EControlClient"
	add_child(control_client)
	return true


func _start_identity(identity: IdentityProvider) -> void:
	if identity == null:
		return

	var init_err := identity.initialize()
	if init_err != OK:
		Info.alert("Failed to initialize Steam\n Make sure it is running.")
		return

	if identity is SteamIdentityProvider:
		identity.auth_ticket_ready.connect(_on_auth_ticket_ready)
		identity.auth_ticket_failed.connect(_on_auth_ticket_failed)
		identity.request_auth_ticket()


func _on_auth_ticket_ready(ticket: String) -> void:
	game_manager.store_auth_ticket(ticket)
	if ticket.is_empty():
		return
	server_bridge.heartbeat_timer.start()


func _on_auth_ticket_failed(message: String) -> void:
	push_error("Steam authentication failed: %s" % message)
	Info.alert("Failed to authenticate with Steam.\n" + message)


func _gather_launch_args() -> PackedStringArray:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args
	return _launch_args_without_editor_script_prefix(OS.get_cmdline_args())


func _launch_args_without_editor_script_prefix(args: PackedStringArray) -> PackedStringArray:
	if OS.has_feature("editor_runtime") and args.size() >= 2:
		return args.slice(2)
	return args


func _abort_startup(message: String) -> void:
	push_error(message)
	printerr(message)
	get_tree().call_deferred("quit", 1)


func mp_print(message: String) -> void:
	print("[%d]: %s" % [id(), message])


func id() -> int:
	if not multiplayer.multiplayer_peer:
		return 1

	return multiplayer.get_unique_id()


func account_id() -> int:
	if context == null or context.identity == null:
		return 0
	return context.identity.player_id()


func display_name() -> String:
	if context == null or context.identity == null:
		return ""
	return context.identity.display_name()


func steam_available() -> bool:
	return context != null and context.identity is SteamIdentityProvider


func mp() -> bool:
	return multiplayer.multiplayer_peer != null


func is_sv() -> bool:
	return is_server


func is_offline_playtest_mode(user_args: PackedStringArray) -> bool:
	return user_args.has("--offline-playtest")
