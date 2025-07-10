extends Node

signal my_lobby_changed
signal player_switched_map(pid: int, map: MapData)
signal player_diconnected(pid: int)
signal player_left_map(pid: int)
signal replay_requested(data: String)

var lobby_id: int
var lobby_members: Array[Member]
var lobby_name: String
var current_map: MapData
var auth_ticket: Dictionary 
var auth_ticket_hex: String
var admin: bool

var map_name_to_time: Dictionary = {}

enum NETWORK_TYPE { ENET, STEAM }
var network_type: NETWORK_TYPE = NETWORK_TYPE.STEAM

@rpc("any_peer", "call_remote", "reliable")
func switched_map(mid: int) -> void:
	if mid == -1:
		player_left_map.emit(multiplayer.get_remote_sender_id())	

	var mm: Maps = MapManager
	var data := mm.get_map_with_id(mid)

	if data:
		player_switched_map.emit(multiplayer.get_remote_sender_id(), data)
	
	var sender := multiplayer.get_remote_sender_id()

	if network_type == NETWORK_TYPE.STEAM:
		var steam_peer: SteamMultiplayerPeer = multiplayer.multiplayer_peer 
		sender = steam_peer.get_steam64_from_peer_id(sender)
	
	get_player(sender).current_map_id = mid	
	my_lobby_changed.emit()

func _ready() -> void:
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.get_ticket_for_web_api.connect(_on_get_ticket_for_web_api)
	Steam.getAuthTicketForWebApi("munost")

func get_player(id: int) -> Member:
	for member in lobby_members:
		if member.id == id:
			return member
	
	return null

func get_player_name(peer_id: int) -> String:
	if network_type == NETWORK_TYPE.STEAM:
		var steam_peer: SteamMultiplayerPeer = multiplayer.multiplayer_peer 
		var steam_id := steam_peer.get_steam64_from_peer_id(peer_id)
		return Steam.getFriendPersonaName(steam_id)
	else:
		return str(peer_id)

func _on_get_ticket_for_web_api(_auth_ticket: int, _result: int, _ticket_size: int, ticket_buffer: Array) -> void:
	auth_ticket_hex = PackedByteArray(ticket_buffer).hex_encode()
	admin = await Http.check_admin()

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		update_lobby_members()
		my_lobby_changed.emit()

func update_lobby_members() -> void:
	lobby_members.clear()

	var num_members := Steam.getNumLobbyMembers(lobby_id)
	for i in range(0, num_members):
		var member_steam_id := Steam.getLobbyMemberByIndex(lobby_id, i)
		var member_steam_name := Steam.getFriendPersonaName(member_steam_id)
		var steam_peer: SteamMultiplayerPeer = multiplayer.multiplayer_peer 
		var peer_id := steam_peer.get_peer_id_from_steam64(member_steam_id)
		lobby_members.append(Member.new(member_steam_id, member_steam_name, peer_id))
	
	my_lobby_changed.emit()

func set_lobby_name(lname: String) -> void:
	self.lobby_name = lname 

func leave() -> void:
	if lobby_id == 0: return

	Steam.leaveLobby(Lobby.lobby_id)
	lobby_id = 0
	lobby_members.clear()
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	my_lobby_changed.emit()

func join_steam_lobby(lid: int) -> void:
	leave()
	var steam_peer := SteamMultiplayerPeer.new()
	steam_peer.connect_lobby(lid)
	multiplayer.multiplayer_peer = steam_peer
	_init_steam_callbacks(steam_peer)
	network_type = NETWORK_TYPE.STEAM

func create_steam_lobby(type: SteamMultiplayerPeer.LobbyType, max_members: int) -> void:
	var steam_peer := SteamMultiplayerPeer.new()
	steam_peer.create_lobby(type, max_members)
	multiplayer.multiplayer_peer = steam_peer
	_init_steam_callbacks(steam_peer)
	network_type = NETWORK_TYPE.STEAM

func _init_steam_callbacks(p: SteamMultiplayerPeer) -> void:
	#p.lobby_chat_update.connect(_on_steam_lobby_chat_update)
	p.lobby_created.connect(_on_steam_lobby_created)
	p.peer_connected.connect(_on_enet_peer_connected)
	p.peer_disconnected.connect(_on_enet_peer_disconnected)

func _init_enet_callbacks(p: ENetMultiplayerPeer) -> void:
	p.peer_connected.connect(_on_enet_peer_connected)
	p.peer_disconnected.connect(_on_enet_peer_disconnected)

func _on_enet_peer_connected(id: int) -> void:
	if network_type == NETWORK_TYPE.ENET:
		lobby_members.append(Member.new(id, "Unnamed Player", id))
	else:
		update_lobby_members()

	my_lobby_changed.emit()	

	if current_map:
		switched_map.rpc(current_map.mid)

func _on_enet_peer_disconnected(id: int) -> void:
	if network_type == NETWORK_TYPE.ENET:
		for i in range(len(lobby_members)):
			var m := lobby_members[i]
			if m.id == id:
				lobby_members.remove_at(i)
				break	
	else:
		update_lobby_members()
	
	my_lobby_changed.emit()
	player_diconnected.emit(id)

func _on_steam_lobby_created(result: int, this_lobby_id: int) -> void:
	if result != 1: return

	Lobby.lobby_id = this_lobby_id
	Steam.setLobbyJoinable(this_lobby_id, true)
	Steam.setLobbyData(this_lobby_id, "name", lobby_name)
	Steam.allowP2PPacketRelay(true)

func create_enet_lobby() -> void:
	var enet_peer := ENetMultiplayerPeer.new()
	enet_peer.create_client("127.0.0.1", 8008)
	multiplayer.multiplayer_peer = enet_peer
	_init_enet_lobby(enet_peer)
	network_type = NETWORK_TYPE.ENET
	
func _init_enet_lobby(p: ENetMultiplayerPeer) -> void:
	lobby_members.clear()
	lobby_id = -1
	lobby_members.append(Member.new(multiplayer.get_unique_id(), "Me", net_id()))
	my_lobby_changed.emit()
	_init_enet_callbacks(p)

func net_id() -> int:
	return multiplayer.get_unique_id()

func join_enet_lobby() -> void:
	var enet_peer := ENetMultiplayerPeer.new()
	enet_peer.create_server(8008, 10)
	multiplayer.multiplayer_peer = enet_peer
	_init_enet_lobby(enet_peer)
	network_type = NETWORK_TYPE.ENET
	

class Member:
	var id: int
	var name: String
	var net_id: int
	var current_map_id: int	

	func _init(m_id: int, m_name: String, pnet_id: int, current_map_id := -1) -> void:
		self.id = m_id
		self.name = m_name
		self.net_id = pnet_id
		self.current_map_id = current_map_id
