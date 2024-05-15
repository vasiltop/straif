extends Node

var steam_id: int = 0
var steam_username: String = ""

func _ready():
	pass
	#try_connect_to_steam()
	

func try_connect_to_steam():
	var result = Steam.steamInitEx()
	
	if result['status'] > 0:
		print("Failed to initialize Steam. Shutting down. %s" % result)
		get_tree().quit()

	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

	var is_owned = Steam.isSubscribed()
	if is_owned == false:
		print("User does not own this game")
		get_tree().quit()
		
func _process(delta):
	Steam.run_callbacks()
