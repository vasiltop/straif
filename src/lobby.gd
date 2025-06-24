extends Node

signal my_lobby_changed
signal player_switched_map(pid: int, map: MapData)
signal player_diconnected(pid: int)

var lobby_id: int
var lobby_members: Array[Member]
var peer: MultiplayerPeer
var lobby_name: String
var current_map: MapData

enum NETWORK_TYPE { ENET, STEAM }
var network_type: NETWORK_TYPE = NETWORK_TYPE.STEAM

@rpc("any_peer", "call_remote", "reliable")
func test() -> void:
	print("received test")

@rpc("any_peer", "call_remote", "reliable")
func switched_map(mid: int) -> void:
	var mm: Maps = MapManager
	var data := mm.get_map_with_id(mid)
	if not data: return

	player_switched_map.emit(multiplayer.get_remote_sender_id(), data)
	print("Player %d switched to map %s" % [multiplayer.get_remote_sender_id(), data.name])

func _ready() -> void:
	Steam.lobby_joined.connect(_on_lobby_joined)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		update_lobby_members()
		my_lobby_changed.emit()

func _on_steam_lobby_chat_update() -> void:
	pass

func update_lobby_members() -> void:
	lobby_members.clear()

	var num_members := Steam.getNumLobbyMembers(lobby_id)
	for i in range(0, num_members):
		var member_steam_id := Steam.getLobbyMemberByIndex(lobby_id, i)
		var member_steam_name := Steam.getFriendPersonaName(member_steam_id)
		lobby_members.append(Member.new(member_steam_id, member_steam_name))

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
		print("Enet peer Connected: %s" % id)
		lobby_members.append(Member.new(id, "Unnamed Player"))
	else:
		update_lobby_members()

	my_lobby_changed.emit()	

	if current_map:
		switched_map.rpc(current_map.mid)

func _on_enet_peer_disconnected(id: int) -> void:
	if network_type == NETWORK_TYPE.ENET:
		print("Enet peer Disconnected: %s" % id)
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
	print("Created steam lobby: %s" % this_lobby_id)
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
	lobby_members.append(Member.new(multiplayer.get_unique_id(), "Me"))
	my_lobby_changed.emit()
	_init_enet_callbacks(p)

func join_enet_lobby() -> void:
	var enet_peer := ENetMultiplayerPeer.new()
	enet_peer.create_server(8008, 10)
	multiplayer.multiplayer_peer = enet_peer
	_init_enet_lobby(enet_peer)
	network_type = NETWORK_TYPE.ENET
	

class Member:
	var id: int
	var name: String

	func _init(m_id: int, m_name: String) -> void:
		self.id = m_id
		self.name = m_name
