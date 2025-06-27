extends Node

func _ready() -> void:
	var init_res := Steam.steamInitEx(480, true)

	if init_res.status != Steam.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize, Steam: %s" % init_res)

	print("Logged into steam with id: %d" % Steam.getSteamID())
