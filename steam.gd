extends Node

var steam_id: int = 0
var steam_username: String = ""
var lobby_id: int = 0
var lobby_members: Array = []

var potential_lobby: int = 0

func _ready():
	Steam.lobby_joined.connect(on_lobby_joined)
	Steam.lobby_created.connect(on_lobby_created)
	try_connect_to_steam()

func on_lobby_joined(id: int, permissions: int, locked: bool, response: int):
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var fail_reason: String
		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."
		Notify.info("Failed to join this chat room: %s" % fail_reason)
		return
		
	lobby_id = id
	Notify.info("Joined a lobby: %d" % lobby_id)
	lobby_members = get_lobby_members(lobby_id)

func on_lobby_created(connect: int, id: int) -> void:
	if connect != 1: return
	
	lobby_id = id
	Notify.info("Created a lobby: %s" % lobby_id)

	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "name", steam_username + "'s Lobby")
	var set_relay: bool = Steam.allowP2PPacketRelay(true)

func try_connect_to_steam():
	var result = Steam.steamInitEx()
	
	if result['status'] > 0:
		Notify.info("Failed to initialize Steam. Shutting down. %s" % result)
		get_tree().quit()

	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

	var is_owned = Steam.isSubscribed()
	if is_owned == false:
		Notify.info("User does not own this game")
		get_tree().quit()
		
func _process(delta):
	Steam.run_callbacks()
	
func create_lobby():
	if lobby_id != 0: return
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 10)
	
func get_lobby_members(id: int) -> Array:

	var num_of_members: int = Steam.getNumLobbyMembers(id)
	var members = []
	for i in range(num_of_members):
		var member_steam_id: int = Steam.getLobbyMemberByIndex(id, i)
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		members.append({"steam_id":member_steam_id, "steam_name":member_steam_name})
	
	return members
	
func leave_lobby():
	if lobby_id == 0: return
	Notify.info("Left lobby: " + str(lobby_id))
	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	for member in lobby_members:
		if member['steam_id'] != steam_id:
			Steam.closeP2PSessionWithUser(member['steam_id'])

	lobby_members.clear()
