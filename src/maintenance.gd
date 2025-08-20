extends Control

func _physics_process(delta: float) -> void:
	if not Global.game_manager.maintenance:
		get_tree().change_scene_to_file("res://src/menus/main/main_menu.tscn")
