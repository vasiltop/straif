extends Node

signal my_lobby_changed

var lobby_id: int
var lobby_members: Array[Member]

func _ready() -> void:
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
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
	Steam.leaveLobby(Lobby.lobby_id)
	Lobby.lobby_id = 0
	my_lobby_changed.emit()

class Member:
	var id: int
	var name: String

	func _init(m_id: int, m_name: String) -> void:
		self.id = m_id
		self.name = m_name
