class_name GameManager extends Node

signal player_diconnected(pid: int)
signal replay_requested(data: String)
signal maintenance_changed

const SERVER_BROWSER_PING_INTERVAL := 5
const VALID_AIM_SCENARIOS := ["gridshot", "flick", "tracking"]

var current_map: MapData
var current_mode := "target"
var current_aim_scenario := "gridshot"
var auth_ticket_hex: String
var admin: bool
var maintenance: bool
var is_target_mode := true
var map_name_to_pb_info: Dictionary[String, PbInfo]
var is_server := false
var port: int
var max_players: int
var _server_browser_ping_timer: BetterTimer
var server_name: String
var current_pvp_map: String
var current_pvp_mode: String
var player_count: int

var _options: RuntimeOptions
var _server_registry: ServerRegistry
var _map_manager: MapManager


class PbInfo:
	var mode_to_map_info: Dictionary[String, Dictionary] = {
		"target": {"total": 0, "position": 0, "pb": INF},
		"bhop": {"total": 0, "position": 0, "pb": INF},
	}

	func _init(total := 0, position := 0, pb := INF) -> void:
		for mode: String in ["target", "bhop"]:
			self.mode_to_map_info[mode].total = total
			self.mode_to_map_info[mode].position = position
			self.mode_to_map_info[mode].pb = pb


var weapons: Array[WeaponData] = [null]

var pvp_mode_to_map := {
	"deathmatch": "res://src/maps/deathmatch.tscn", "elimination": "res://src/maps/elimination.tscn"
}


func _init(options: RuntimeOptions, server_registry: ServerRegistry, map_manager: MapManager) -> void:
	_options = options
	_server_registry = server_registry
	_map_manager = map_manager
	is_server = options.role == RuntimeOptions.Role.DEDICATED_SERVER

	var path := "res://src/player/weapon/resources/"
	var dir := DirAccess.open(path)

	for file in dir.get_files():
		if file.ends_with(".tres"):
			weapons.append(load(path + file))


func store_auth_ticket(ticket: String) -> void:
	auth_ticket_hex = ticket


func get_weapon_index(weapon: WeaponData) -> int:
	if weapon == null:
		return 0

	for i in range(1, len(weapons)):
		var w := weapons[i]
		if w.name == weapon.name:
			return i

	return -1


func get_weapon_from_index(index: int) -> WeaponData:
	return weapons[index]


func get_current_aim_scenario() -> String:
	if current_aim_scenario in VALID_AIM_SCENARIOS:
		return current_aim_scenario
	return VALID_AIM_SCENARIOS[0]


func init_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_options.port, _options.max_players)
	if err != OK:
		push_error("Failed to create server on port %d: %s" % [_options.port, error_string(err)])
		return

	multiplayer.multiplayer_peer = peer

	self.is_server = true
	self.port = _options.port
	self.max_players = _options.max_players
	self.current_pvp_mode = _options.mode
	self.server_name = _options.server_name
	self.current_pvp_map = _map_manager.get_random_map(_options.mode)

	get_tree().call_deferred("change_scene_to_file", pvp_mode_to_map[_options.mode])

	_server_browser_ping_timer = BetterTimer.new(self, SERVER_BROWSER_PING_INTERVAL, _publish_server_snapshot)
	_server_browser_ping_timer.start()

	print("Created server on port %d." % _options.port)


func _publish_server_snapshot() -> void:
	if _server_registry == null:
		return

	var map_name := current_pvp_map.trim_suffix(".tscn")
	var snapshot := {
		"port": port,
		"name": server_name,
		"mode": current_pvp_mode,
		"map": map_name,
		"player_count": player_count,
		"max_players": max_players,
	}

	var err: Error = await _server_registry.publish(snapshot)
	if err != OK:
		push_warning("Failed to publish server snapshot: %s" % error_string(err))


@rpc("authority", "call_remote", "reliable")
func _server_ready(mode: String) -> void:
	if not pvp_mode_to_map.has(mode):
		push_error("Server sent unknown pvp mode: %s" % mode)
		return
	current_pvp_mode = mode
	get_tree().change_scene_to_file(pvp_mode_to_map[mode])


func connect_to_server(ip: String, port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to create client for %s:%d: %s" % [ip, port, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer


func on_peer_connected(id: int) -> void:
	_log("Connected to player %d" % id)

	if is_server:
		_server_ready.rpc_id(id, current_pvp_mode)
		player_count += 1


func on_peer_disconnected(id: int) -> void:
	_log("Disconnected from player %d" % id)
	player_diconnected.emit(id)

	if is_server:
		player_count = maxi(0, player_count - 1)


func on_connection_failed() -> void:
	Info.alert("Failed to connect to server.")


func on_server_disconnected() -> void:
	Info.alert("Disconnected from the server.")


func _local_peer_id() -> int:
	if not multiplayer.multiplayer_peer:
		return 1
	return multiplayer.get_unique_id()


func _log(message: String) -> void:
	print("[%d]: %s" % [_local_peer_id(), message])
