extends Node

signal my_lobby_changed

var lobby_id: int
var lobby_members: Array[Member]
var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()

func _ready() -> void:
	peer.lobby_joined.connect(_on_lobby_joined)
	peer.lobby_chat_update.connect(_on_lobby_chat_update)
	multiplayer.peer_connected.connect(func() -> void: print("connected"))

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("joined")
	lobby_members.clear()

	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		update_lobby_members()
		my_lobby_changed.emit()

func _on_lobby_chat_update() -> void:
	pass

func update_lobby_members() -> void:
	lobby_members.clear()

	var num_members := Steam.getNumLobbyMembers(lobby_id)
	for i in range(0, num_members):
		var member_steam_id := Steam.getLobbyMemberByIndex(lobby_id, i)
		var member_steam_name := Steam.getFriendPersonaName(member_steam_id)
		lobby_members.append(Member.new(member_steam_id, member_steam_name))

func leave() -> void:
	if lobby_id == 0: return

	Steam.leaveLobby(Lobby.lobby_id)
	lobby_id = 0
	lobby_members.clear()
	peer.close()
	multiplayer.multiplayer_peer = null
	my_lobby_changed.emit()

func join(lid: int) -> void:
	leave()
	peer.connect_lobby(lid)
	multiplayer.multiplayer_peer = peer

func create(type: SteamMultiplayerPeer.LobbyType, max_members: int) -> void:
	peer.create_lobby(type, max_members)
	multiplayer.multiplayer_peer = peer

class Member:
	var id: int
	var name: String

	func _init(m_id: int, m_name: String) -> void:
		self.id = m_id
		self.name = m_name
