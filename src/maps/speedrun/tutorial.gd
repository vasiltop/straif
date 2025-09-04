extends Node3D

@export var movement_label: Label3D
@export var restart_label: Label3D
@export var leaderboard_label: Label3D

func _ready() -> void:
	movement_label.text = "To move, use the %s%s%s%s keys.\n To jump, use the %s key." % [
		Global.settings_manager.get_keybind_string("up"),
		Global.settings_manager.get_keybind_string("left"),
		Global.settings_manager.get_keybind_string("down"),
		Global.settings_manager.get_keybind_string("right"),
		Global.settings_manager.get_keybind_string("jump"),
	]
	
	restart_label.text = "To restart, use the %s key." % Global.settings_manager.get_keybind_string("restart")
	
	leaderboard_label.text = "To view the leaderboard, use the %s key." % Global.settings_manager.get_keybind_string("leaderboard")
