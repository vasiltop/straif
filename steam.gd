extends Node

var steam_id: int = 0
var steam_username: String = ""
var lobby_id: int = 0
var lobby_members: Array = []

var potential_lobby: int = 0

var spawned_players: Array = []

func _ready():
	Steam.lobby_joined.connect(on_lobby_joined)
	Steam.lobby_created.connect(on_lobby_created)
	Steam.p2p_session_request.connect(p2p_session_request)
	Steam.p2p_session_connect_fail.connect(p2p_session_connect_fail)
	Steam.lobby_chat_update.connect(on_lobby_chat_update)
	try_connect_to_steam()

func read_packet():
	pass
	
func p2p_session_request(remote_id: int):
	var this_requester: String = Steam.getFriendPersonaName(remote_id)
	print("%s is requesting a P2P session" % this_requester)

	Steam.acceptP2PSessionWithUser(remote_id)
	Packet.make_p2p_handshake()
	
func p2p_session_connect_fail(steam_id: int, session_error: int):
	if session_error == 0:
		Notify.info("WARNING: Session failure with %s: no error given" % steam_id)
	elif session_error == 1:
		Notify.info("WARNING: Session failure with %s: target user not running the same game" % steam_id)
	elif session_error == 2:
		Notify.info("WARNING: Session failure with %s: local user doesn't own app / game" % steam_id)
	elif session_error == 3:
		Notify.info("WARNING: Session failure with %s: target user isn't connected to Steam" % steam_id)
	elif session_error == 4:
		Notify.info("WARNING: Session failure with %s: connection timed out" % steam_id)
	elif session_error == 5:
		Notify.info("WARNING: Session failure with %s: unused" % steam_id)
	else:
		Notify.info("WARNING: Session failure with %s: unknown error %s" % [steam_id, session_error])
	
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
	Packet.make_p2p_handshake()

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
	read_packet()
	
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

func on_lobby_chat_update(this_lobby_id: int, change_id: int, making_change_id: int, chat_state: int) -> void:
	var changer_name: String = Steam.getFriendPersonaName(change_id)

	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		lobby_members = get_lobby_members(lobby_id)
		Packet.make_p2p_handshake()
		Notify.info("%s has joined the lobby." % changer_name)
	else:
		lobby_members = get_lobby_members(lobby_id)

	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		Notify.info("%s has left the lobby." % changer_name)

	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		Notify.info("%s has been kicked from the lobby." % changer_name)

	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		Notify.info("%s has been banned from the lobby." % changer_name)

func join_lobby(id: int):
	leave_lobby()
	Steam.joinLobby(id)
	
func is_id_spawned(id: int) -> Node3D :
	for player in spawned_players:
		if player.steam_id == id:
			return player
	return null
