class_name GameManager extends Node

signal my_lobby_changed
signal player_diconnected(pid: int)
signal player_left_map(pid: int)
signal replay_requested(data: String)
signal maintenance_changed

enum NETWORK_TYPE { ENET, STEAM }

var current_map: MapData
var current_mode := "target"
var auth_ticket_hex: String
var admin: bool
var maintenance: bool
var is_target_mode := true
var map_name_to_pb_info: Dictionary[String, PbInfo]

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

func _init() -> void:
	Steam.get_ticket_for_web_api.connect(_on_get_ticket_for_web_api)
	Steam.getAuthTicketForWebApi("munost")

func _on_get_ticket_for_web_api(_auth_ticket: int, _result: int, _ticket_size: int, ticket_buffer: Array) -> void:
	auth_ticket_hex = PackedByteArray(ticket_buffer).hex_encode()
	Global.server_bridge.heartbeat_timer.start()
