extends VSplitContainer
@onready var button = $Navbar/Actions/CreateLobby

func _ready():
	$Navbar/Username.text = "Hello, " + SteamClient.steam_username + "!"
	$Navbar/GameData/GamemodeBhop.pressed.connect($Margin/LevelSelect.set_gamemode_bhop)
	$Navbar/GameData/GamemodeLongjump.pressed.connect($Margin/LevelSelect.set_gamemode_longjump)
	$Navbar/GameData/Lobbies.pressed.connect($Margin/LevelSelect.show_lobbies)
	
	$Navbar/Actions/CreateLobby.pressed.connect(SteamClient.create_lobby)
	$Navbar/Actions/CreateLobby.pressed.connect(view_lobby_info)

func _process(delta):
	
	if SteamClient.lobby_id != 0:
		button.text = "Lobby Info"
	else:
		button.text = "Create Lobby"
		
func view_lobby_info():
	if button.text != "Lobby Info": return
	
	SceneManager.change_scene(SceneManager.SCENES.LOBBY_MENU)
