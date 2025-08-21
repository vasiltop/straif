extends Control

@onready var quit: Button = $Quit

func _ready() -> void:
	Global.game_manager.maintenance_changed.connect(
		func() -> void:
			if not Global.game_manager.maintenance:
				get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
	)
	
	quit.pressed.connect(get_tree().quit)
