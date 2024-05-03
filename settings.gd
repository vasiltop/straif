extends Node

var sens = 0.001
var uuid = ""

var save_file = "user://straif.data"
var base_url = "https://straif.vasiltopalovic.com/"

var prev_room = "res://menus/account/account.tscn"

func toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
