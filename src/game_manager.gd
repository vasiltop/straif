class_name GameManager extends Node

signal my_lobby_changed
signal player_diconnected(pid: int)
signal player_left_map(pid: int)
signal replay_requested(data: String)
signal maintenance_changed

enum NETWORK_TYPE { ENET, STEAM }

const SERVER_BROWSER_PING_INTERVAL := 5

var current_map: MapData
var current_mode := "target"
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

# TODO: Populate this automatically if theres more modes
class PbInfo:
	var mode_to_map_info: Dictionary[String, Dictionary] = {
		"target": {
			"total": 0,
			"position": 0,
			"pb": INF
		},
		"bhop": {
			"total": 0,
			"position": 0,
			"pb": INF
		},
	}
	
	func _init(total := 0, position := 0, pb := INF) -> void:
		for mode: String in ["target", "bhop"]:
			self.mode_to_map_info[mode].total = total
			self.mode_to_map_info[mode].position = position
			self.mode_to_map_info[mode].pb = pb

var weapons: Array[WeaponData] = [null]

var pvp_mode_to_map := {
	"deathmatch": "res://src/maps/deathmatch.tscn"
}

func _init(is_server: bool) -> void:
	if not is_server:
		print("calling web api")
		Steam.get_ticket_for_web_api.connect(_on_get_ticket_for_web_api)
		Steam.getAuthTicketForWebApi("munost")
	
	var path := "res://src/player/weapon/resources/"
	var dir := DirAccess.open(path)
	
	for file in dir.get_files():
		# TODO: Add loading binary packed versions when exporting
		if file.ends_with(".tres"):
			weapons.append(load(path + file))
	
	print("dir files")
	print(dir.get_files())
	print(weapons)

func get_weapon_index(weapon: WeaponData) -> int:
	if weapon == null: return 0
	
	for i in range(1, len(weapons)):
		var w := weapons[i]
		if w.name == weapon.name:
			return i
	
	return -1

func get_weapon_from_index(index: int) -> WeaponData:
	return weapons[index]

func _on_get_ticket_for_web_api(_auth_ticket: int, _result: int, _ticket_size: int, ticket_buffer: Array) -> void:
	auth_ticket_hex = PackedByteArray(ticket_buffer).hex_encode()
	Global.server_bridge.heartbeat_timer.start()

func init_server(server_name: String, port: int, max_players: int, mode: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, max_players)
	Global.multiplayer.multiplayer_peer = peer
	
	self.is_server = true
	self.port = port
	self.max_players = max_players
	self.current_pvp_mode = mode
	self.server_name = server_name
	self.current_pvp_map = Global.map_manager.get_random_map(mode)
	
	get_tree().change_scene_to_file(pvp_mode_to_map[mode])
	
	_server_browser_ping_timer = BetterTimer.new(self, SERVER_BROWSER_PING_INTERVAL, Global.server_bridge.ping_server_browser)
	_server_browser_ping_timer = BetterTimer.new(self, SERVER_BROWSER_PING_INTERVAL, Global.server_bridge.ping_server_browser)
	_server_browser_ping_timer.start()
	
	print("Created server on port %d." % port)

@rpc("authority", "call_remote", "reliable")
func _server_ready() -> void:
	get_tree().change_scene_to_file(pvp_mode_to_map[current_pvp_mode])

func connect_to_server(ip: String, port: int) -> void:
	print(port)
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("209.38.2.30", port)
	Global.multiplayer.multiplayer_peer = peer

func on_peer_connected(id: int) -> void:
	Global.mp_print("Connected to player %d" % id)
	
	if Global.is_sv():
		_server_ready.rpc_id(id)
		player_count += 1

func on_peer_disconnected(id: int) -> void:
	Global.mp_print("Disconnected from player %d" % id)
	player_diconnected.emit(id)
	
	if Global.is_sv():
		player_count -= 1

# only called on client
func on_connected_to_server() -> void:
	pass

# only called on client
func on_connection_failed() -> void:
	Info.alert("Failed to connect to server.")

# only called on client
func on_server_disconnected() -> void:
	Info.alert("Disconnected from the server.")
