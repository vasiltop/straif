extends Node

func _ready():
	$Sens.value = Settings.sens * 1000
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta):
	Settings.sens = $Sens.value / 1000
	print(Settings.sens)
	if Input.is_action_just_pressed("menu"):
		get_tree().change_scene_to_file("res://menus/level_select/level_select.tscn")
