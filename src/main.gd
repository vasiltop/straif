extends Node

const APP_ID := 3850480

func _ready() -> void:
	var init_res := Steam.steamInitEx(APP_ID, true)

	if init_res.status != Steam.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
		Info.alert("Failed to initialize Steam\n Make sure it is running.")

	print("Logged into steam with id: %d" % Steam.getSteamID())
