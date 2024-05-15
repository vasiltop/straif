extends Control

var members = SteamClient.get_lobby_members(SteamClient.lobby_id)

func _ready():
	$MarginContainer/Content/Navbar/HBoxContainer/Back.pressed.connect(back)
	$MarginContainer/Content/Navbar/HBoxContainer/Leave.pressed.connect(leave)
	update_members_label()

func back():
	SceneManager.change_to_previous()

func leave():
	SceneManager.change_to_previous()
	SteamClient.leave_lobby()

func update_members_label():
	var l = $MarginContainer/Content/Margin/Label
	l.text = ""
	for member in members:
		l.text += member.steam_name + "\n"
