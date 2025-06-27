extends Node

func _ready() -> void:
	var init_res := Steam.steamInitEx(480, true)

	if init_res.status != Steam.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize, Steam: %s" % init_res)

	Lobby.auth_ticket = Steam.getAuthSessionTicket()
	Lobby.auth_ticket_hex = PackedByteArray(Lobby.auth_ticket.buffer as Array).hex_encode()
