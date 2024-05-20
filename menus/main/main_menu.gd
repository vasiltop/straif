extends VSplitContainer

@onready var button = $Navbar/Actions/CreateLobby

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Navbar/Username.text = "Hello, " + Steam.getPersonaName() + "!"
	$Navbar/GameData/GamemodeBhop.pressed.connect($Margin/LevelSelect.set_gamemode_bhop)
	$Navbar/GameData/GamemodeLongjump.pressed.connect($Margin/LevelSelect.set_gamemode_longjump)
	$Navbar/GameData/GamemodeKz.pressed.connect($Margin/LevelSelect.set_gamemode_kz)
	$Navbar/GameData/Lobbies.pressed.connect($Margin/LevelSelect.show_lobbies)
	
	$Navbar/Actions/CreateLobby.pressed.connect(SteamClient.create_lobby)
	$Navbar/Actions/CreateLobby.pressed.connect(view_lobby_info)
	$Navbar/Actions/Settings.pressed.connect(open_settings)

func _process(delta):
	
	if SteamClient.lobby_id != 0:
		button.text = "Lobby Info"
	else:
		button.text = "Create Lobby"
		
func view_lobby_info():
	if button.text != "Lobby Info": return
	SceneManager.change_scene(SceneManager.SCENES.LOBBY_MENU)

func open_settings():
	SceneManager.change_scene(SceneManager.SCENES.SETTINGS_MENU)
