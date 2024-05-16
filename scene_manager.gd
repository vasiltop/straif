extends Node
enum SCENES { MAIN_MENU, PAUSE_MENU, LOBBY_MENU, SETTINGS_MENU }

var previous_scene = SCENES.MAIN_MENU

var scene_filenames = {
	SCENES.MAIN_MENU: "res://menus/main/main.tscn",
	SCENES.PAUSE_MENU: "res://menus/pause/pause.tscn",
	SCENES.LOBBY_MENU: "res://menus/lobby/lobby.tscn",
	SCENES.SETTINGS_MENU: "res://menus/settings/settings.tscn"
}

func change_scene(scene: SCENES):
	previous_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file(scene_filenames[scene])

func change_to_previous():
	get_tree().change_scene_to_file(previous_scene)
